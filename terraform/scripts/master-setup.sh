#!/bin/bash

# Configuration
K8S_VERSION="${k8s_version}"
POD_NETWORK_CIDR="${pod_network_cidr}"

# Mise à jour et installation des dépendances
apt-get update
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    jq \
    python3

# Installation Docker (méthode rapide)
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Configuration Docker
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

systemctl enable docker
systemctl start docker

# Désactivation swap
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Modules kernel
cat > /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Sysctl
cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system

# Installation Kubernetes
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet=${K8S_VERSION}-00 kubeadm=${K8S_VERSION}-00 kubectl=${K8S_VERSION}-00
apt-mark hold kubelet kubeadm kubectl

# Initialisation du cluster
PRIVATE_IP=$(hostname -I | awk '{print $1}')
kubeadm init \
  --pod-network-cidr=${POD_NETWORK_CIDR} \
  --apiserver-advertise-address=${PRIVATE_IP} \
  --ignore-preflight-errors=all

# Configuration kubectl
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# Installation Flannel en arrière-plan
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml &

# Génération du token de jointure
kubeadm token create --print-join-command > /join-cluster.sh
chmod +x /join-cluster.sh

# Création du fichier d'inventaire pour Ansible
mkdir -p /tmp/ansible
cat > /tmp/ansible/join-command.txt <<EOF
JOIN_COMMAND=$(cat /join-cluster.sh)
EOF

# Installation de python3 pour Ansible
apt-get install -y python3

echo "✅ Master node setup completed!"
echo "📋 Join command: $(cat /join-cluster.sh)"

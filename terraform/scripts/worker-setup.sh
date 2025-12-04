#!/bin/bash

MASTER_IP=${master_ip}

# Mise à jour du système
apt-get update
apt-get upgrade -y

# Installation des dépendances
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Ajout de la clé GPG de Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Ajout du repository Docker
echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Mise à jour et installation de Docker
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io

# Configuration de Docker pour systemd
mkdir -p /etc/docker
cat <<EOF | tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

# Démarrage et activation de Docker
systemctl enable docker
systemctl start docker

# Installation de kubeadm et kubelet
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubelet=1.28.0-00 kubeadm=1.28.0-00
apt-mark hold kubelet kubeadm

# Désactivation du swap
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Configuration sysctl
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system

# Attente que le master soit prêt
echo "⏳ Waiting for master node to be ready..."
while ! nc -z $MASTER_IP 6443; do
  sleep 5
done

echo "✅ Installation verification..."
which docker && echo "Docker installed" || echo "Docker NOT installed"
which kubeadm && echo "kubeadm installed" || echo "kubeadm NOT installed"
which kubectl && echo "kubectl installed" || echo "kubectl NOT installed"

# Créer un fichier marqueur pour indiquer que le script a terminé
touch /var/tmp/setup-completed

echo "✅ Master is ready! Joining cluster..."

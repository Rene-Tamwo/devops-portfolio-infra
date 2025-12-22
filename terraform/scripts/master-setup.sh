#!/bin/bash

# Log tout
exec > >(tee /var/log/user-data.log) 2>&1
set -x

echo "🚀 Starting master setup at $(date)"

# Vérifier la connexion internet
echo "📡 Checking internet connection..."
ping -c 3 google.com || echo "⚠️ No internet connection"

# Mise à jour
apt-get update
apt-get upgrade -y

# Installation Docker avec la bonne version
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Configuration Docker pour Kubernetes (CRITIQUE)
mkdir -p /etc/docker
cat <<EOF | tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "registry-mirrors": [],
  "live-restore": true
}
EOF

# Redémarrer Docker
systemctl daemon-reload
systemctl restart docker
systemctl enable docker

# Charger les modules kernel nécessaires
modprobe overlay
modprobe br_netfilter

cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

# Configuration sysctl
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system

# Désactivation swap
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Installation Kubernetes (version explicite)
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubelet=1.28.0-00 kubeadm=1.28.0-00 kubectl=1.28.0-00
apt-mark hold kubelet kubeadm kubectl

# Pré-télécharger les images (évite les timeout)
kubeadm config images pull --cri-socket=unix:///var/run/dockershim/docker.sock

# Initialiser le cluster avec Docker comme runtime
kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --cri-socket=unix:///var/run/dockershim/docker.sock \
  --ignore-preflight-errors=all

# Configuration kubectl pour ubuntu user
mkdir -p /home/ubuntu/.kube
cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown -R ubuntu:ubuntu /home/ubuntu/.kube

# Configuration kubectl pour root
mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config

# Installation Flannel (doit être fait après kubeconfig)
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# Générer token de join
kubeadm token create --print-join-command > /join-cluster.sh
chmod +x /join-cluster.sh

# Attendre que le cluster soit prêt
echo "⏳ Waiting for cluster to be ready..."
for i in {1..30}; do
  if kubectl get nodes 2>/dev/null | grep -q "$(hostname)"; then
    echo "✅ Cluster is ready!"
    break
  fi
  echo "⏳ Still waiting... ($i/30)"
  sleep 10
done

# Afficher l'état
echo "🔍 Cluster status:"
kubectl get nodes
kubectl get pods -n kube-system

# Créer un marqueur de fin
touch /var/lib/cloud/instance/boot-finished
echo "✅ Master setup COMPLETED at $(date)"
echo "🔑 Join command:"
cat /join-cluster.sh

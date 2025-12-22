#!/bin/bash

# Configuration du logging
exec > >(tee /var/log/user-data.log) 2>&1
set -x

echo "🚀🚀🚀 STARTING MASTER SETUP - $(date) 🚀🚀🚀"

# 1. Mise à jour système
echo "📦 Updating system..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -q

# 2. Installation Docker (version stable)
echo "🐳 Installing Docker..."
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

systemctl daemon-reload
systemctl restart docker
systemctl enable docker

# Vérifier Docker
docker --version || echo "❌ Docker install failed"

# 3. Désactiver swap
echo "⚡ Disabling swap..."
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# 4. Configuration réseau
echo "🌐 Configuring network..."
cat > /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system

# 5. Installation Kubernetes (VERSION SIMPLIFIÉE)
echo "🎯 Installing Kubernetes..."
# Ajout du repo
curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list

# Installation
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# Vérification
echo "✅ Installed versions:"
kubeadm version || echo "❌ kubeadm not installed"
kubectl version --client 2>/dev/null || echo "❌ kubectl not installed"

# 6. Initialisation du cluster (SIMPLIFIÉE)
echo "🔄 Initializing Kubernetes cluster..."
kubeadm init --pod-network-cidr=10.244.0.0/16 --ignore-preflight-errors=all

# 7. Configuration kubectl
echo "⚙️ Setting up kubectl..."
mkdir -p /home/ubuntu/.kube
cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown -R ubuntu:ubuntu /home/ubuntu/.kube

mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config

# 8. Installation réseau Flannel
echo "🔗 Installing Flannel network..."
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# 9. Génération du token de join
echo "🔑 Generating join token..."
kubeadm token create --print-join-command > /join-cluster.sh
chmod +x /join-cluster.sh

# 10. Vérification finale
echo "📊 Final verification..."
kubectl get nodes
kubectl get pods --all-namespaces

# 11. Marqueur de fin
touch /var/lib/cloud/instance/boot-finished
echo "🎉🎉🎉 MASTER SETUP COMPLETED SUCCESSFULLY! - $(date) 🎉🎉🎉"
echo ""
echo "🔗 Join command:"
cat /join-cluster.sh

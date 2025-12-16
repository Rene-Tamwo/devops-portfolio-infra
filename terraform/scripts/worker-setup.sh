#!/bin/bash

# Configuration
K8S_VERSION="1.28.0"
MASTER_IP="${master_ip}"  # Remplacé par Terraform

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
apt-get install -y kubelet=${K8S_VERSION}-00 kubeadm=${K8S_VERSION}-00
apt-mark hold kubelet kubeadm

echo "✅ Worker node setup completed!"
echo "⏳ Waiting for master node to be ready for joining..."

#!/bin/bash

set -x
exec > /var/log/user-data.log 2>&1

echo "🚀 Starting worker setup at $(date)"

MASTER_IP="${master_ip}"

# Mise à jour
apt-get update
apt-get upgrade -y

# Installation Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Configuration Docker
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

systemctl daemon-reload
systemctl restart docker
systemctl enable docker

# Modules kernel
modprobe overlay
modprobe br_netfilter

cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

# Sysctl
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system

# Désactivation swap
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Installation Kubernetes
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubelet=1.28.0-00 kubeadm=1.28.0-00
apt-mark hold kubelet kubeadm

# Attendre que le master soit prêt
echo "⏳ Waiting for master to be ready..."
for i in {1..60}; do
  if nc -z $MASTER_IP 6443; then
    echo "✅ Master API server is reachable"
    break
  fi
  echo "⏳ Still waiting... ($i/60)"
  sleep 10
done

# Récupérer la commande join
echo "📥 Getting join command from master..."
JOIN_CMD=""
for i in {1..30}; do
  # Essayer plusieurs méthodes pour récupérer la commande
  if ssh-keyscan -H $MASTER_IP >> ~/.ssh/known_hosts 2>/dev/null; then
    JOIN_CMD=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$MASTER_IP "cat /join-cluster.sh 2>/dev/null" || true)
    
    if [ -n "$JOIN_CMD" ]; then
      echo "✅ Join command received: $JOIN_CMD"
      break
    fi
  fi
  
  echo "⏳ Retrying to get join command... ($i/30)"
  sleep 10
done

# Rejoindre le cluster
if [ -n "$JOIN_CMD" ]; then
  echo "🚀 Joining Kubernetes cluster..."
  
  # Nettoyer si déjà joint
  kubeadm reset -f 2>/dev/null || true
  
  # Rejoindre avec le bon socket CRI
  $JOIN_CMD --cri-socket=unix:///var/run/dockershim/docker.sock --ignore-preflight-errors=all
  
  echo "✅ Worker joined cluster!"
else
  echo "⚠️ Could not get join command, worker will wait for Ansible"
fi

# Marqueur de fin
touch /var/lib/cloud/instance/boot-finished
echo "✅ Worker setup COMPLETED at $(date)"

#!/bin/bash

# Activer le logging détaillé
set -x
exec > /var/log/user-data.log 2>&1

echo "🚀 Starting worker setup at $(date)"

MASTER_IP="${master_ip}"

# Mise à jour et installation Docker
apt-get update
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Désactivation swap
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# NOUVELLE MÉTHODE pour installer Kubernetes (Ubuntu 22.04+)
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubelet=1.28.0-1.1 kubeadm=1.28.0-1.1
apt-mark hold kubelet kubeadm

# Attendre que le master soit complètement prêt
echo "⏳ Waiting for master node to be ready..."
for i in {1..30}; do
  if nc -z $MASTER_IP 22 && ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$MASTER_IP "kubectl get nodes 2>/dev/null"; then
    echo "✅ Master is ready and cluster is initialized"
    break
  fi
  echo "⏳ Still waiting... ($i/30)"
  sleep 10
done

# Récupérer la commande join depuis le master
echo "📥 Getting join command from master..."
for i in {1..10}; do
  JOIN_CMD=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$MASTER_IP "cat /join-cluster.sh 2>/dev/null" || true)
  if [ -n "$JOIN_CMD" ]; then
    echo "✅ Join command received"
    break
  fi
  sleep 10
done

# Exécuter la commande join
if [ -n "$JOIN_CMD" ]; then
  echo "🚀 Joining Kubernetes cluster..."
  $JOIN_CMD --ignore-preflight-errors=all
  
  echo "✅ Worker joined cluster!"
else
  echo "❌ Failed to get join command from master"
  echo "⚠️ Worker will wait for Ansible to join it later"
fi

# Marquer la fin de l'installation
touch /var/lib/cloud/instance/boot-finished

echo "✅ Worker setup COMPLETED at $(date)"
echo "📋 Verification:"
kubeadm version
docker --version

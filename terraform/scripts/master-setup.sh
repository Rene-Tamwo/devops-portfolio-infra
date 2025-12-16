#!/bin/bash

# Activer le logging détaillé
set -x
exec > /var/log/user-data.log 2>&1

echo "🚀 Starting master setup at $(date)"

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
apt-get install -y kubelet=1.28.0-1.1 kubeadm=1.28.0-1.1 kubectl=1.28.0-1.1
apt-mark hold kubelet kubeadm kubectl

# Initialisation du cluster
kubeadm init --pod-network-cidr=10.244.0.0/16 --ignore-preflight-errors=all

# Configuration kubectl pour l'utilisateur ubuntu (CRITIQUE pour Ansible)
mkdir -p /home/ubuntu/.kube
cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown -R ubuntu:ubuntu /home/ubuntu/.kube

# Configuration kubectl pour root aussi
mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config
chown -R root:root /root/.kube

# Installation Flannel en tant que ubuntu
sudo -u ubuntu kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# Génération du token
kubeadm token create --print-join-command > /join-cluster.sh
chmod +x /join-cluster.sh

# Attendre que les pods système démarrent
sleep 30

# Vérification
echo "🔍 Cluster status:"
sudo -u ubuntu kubectl get nodes
sudo -u ubuntu kubectl get pods -n kube-system

# Marquer la fin de l'installation
touch /var/lib/cloud/instance/boot-finished

echo "✅ Master setup COMPLETED at $(date)"
echo "📋 Verification:"
kubeadm version
sudo -u ubuntu kubectl version --client
docker --version

# Afficher la commande join pour debug
echo "🔑 Join command:"
cat /join-cluster.sh

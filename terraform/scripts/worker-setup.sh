#!/bin/bash

# Récupération de l'IP du master depuis Terraform
MASTER_IP="${master_ip}"

# Mise à jour et installation Docker
apt-get update
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Désactivation swap
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Installation Kubernetes
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet kubeadm
apt-mark hold kubelet kubeadm

echo "✅ Worker setup complete! Waiting for master..."

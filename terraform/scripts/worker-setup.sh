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

# NOUVELLE MÉTHODE pour installer Kubernetes (Ubuntu 22.04+)
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubelet=1.28.0-1.1 kubeadm=1.28.0-1.1
apt-mark hold kubelet kubeadm

# Marquer la fin de l'installation
touch /var/lib/cloud/instance/boot-finished

# Créer un fichier de status
cat <<EOF > /tmp/setup-status.txt
✅ Setup completed at: $(date)
✅ Docker: $(docker --version)
✅ kubeadm: $(kubeadm version -o short)
✅ kubelet: $(kubelet --version)
EOF

cat /tmp/setup-status.txt



echo "✅ Worker setup complete! Waiting for master..."

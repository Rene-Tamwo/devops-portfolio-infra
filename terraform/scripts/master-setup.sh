#!/bin/bash

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

# Configuration kubectl
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# Installation Flannel
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# Génération du token
kubeadm token create --print-join-command > /join-cluster.sh
chmod +x /join-cluster.sh


# Marquer la fin de l'installation
touch /var/lib/cloud/instance/boot-finished

# Créer un fichier de status
cat <<EOF > /tmp/setup-status.txt
✅ Setup completed at: $(date)
✅ Docker: $(docker --version)
✅ kubeadm: $(kubeadm version -o short)
✅ kubelet: $(kubelet --version)
✅ kubectl: $(kubectl version --client -o json | jq -r '.clientVersion.gitVersion')
EOF

cat /tmp/setup-status.txt


echo "✅ Master setup complete!"

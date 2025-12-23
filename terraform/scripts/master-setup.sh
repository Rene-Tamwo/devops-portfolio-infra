#!/bin/bash

# Logging
exec > >(tee /var/log/user-data.log) 2>&1
set -x

echo "🚀 STARTING BASIC MASTER SETUP - $(date)"

# Installer seulement Docker pour commencer
apt-get update
apt-get install -y docker.io

# Vérifier que Docker fonctionne
docker --version
systemctl enable docker
systemctl start docker

# Créer le marqueur de fin
touch /var/lib/cloud/instance/boot-finished
echo "✅ BASIC SETUP COMPLETE - Kubernetes will be installed by Ansible"
echo "📝 Ansible will handle the rest of the setup"

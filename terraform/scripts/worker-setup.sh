#!/bin/bash

# Logging
exec > >(tee /var/log/user-data.log) 2>&1
set -x

echo "🚀 STARTING BASIC WORKER SETUP - $(date)"

# Installer seulement Docker
apt-get update
apt-get install -y docker.io

# Vérifier Docker
docker --version
systemctl enable docker
systemctl start docker

# Marqueur de fin
touch /var/lib/cloud/instance/boot-finished
echo "✅ BASIC WORKER SETUP COMPLETE"

#!/bin/bash

set -e

echo "=== Updating package index ==="
sudo apt-get update

echo "=== Installing required packages ==="
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

echo "=== Adding Docker's official GPG key ==="
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "=== Setting up Docker repository ==="
echo \
  "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "=== Updating package index (with Docker repo) ==="
sudo apt-get update

echo "=== Installing Docker Engine, CLI, containerd, Buildx, and Compose plugin ==="
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "=== Running test Docker container ==="
sudo docker run hello-world

echo "=== Adding current user to 'docker' group ==="
sudo usermod -aG docker $USER

echo "✅ Docker installation complete!"
echo "⚠️ Please log out and log back in, or run 'newgrp docker' to apply group changes."

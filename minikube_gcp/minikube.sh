#!/bin/bash

# shell: minikube_setup.sh
# purpose: 安裝並啟動 minikube（適用 Ubuntu 22.04）

set -e

# 色彩定義
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# 檢查是否為 root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}請使用 root（sudo）執行此腳本${NC}"
    exit 1
fi

# 檢查是否為 Ubuntu 系統
if ! grep -qi "ubuntu" /etc/os-release; then
    echo -e "${RED}此腳本僅支援 Ubuntu 系統${NC}"
    exit 1
fi

echo -e "${GREEN}開始安裝 Minikube...${NC}"

# 1. 關閉 Swap
echo "關閉 Swap..."
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# 2. 安裝依賴工具
echo "安裝必要工具..."
apt-get update -y
apt-get install -y curl apt-transport-https ca-certificates gnupg lsb-release conntrack

# 3. 安裝 Docker（Minikube 可使用 Docker 作為 Driver）
echo "安裝 Docker..."
curl -fsSL https://get.docker.com | sh
systemctl enable docker
systemctl start docker

# 4. 安裝 kubectl
echo "安裝 kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# 5. 安裝 Minikube
echo "安裝 Minikube..."
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
install minikube-linux-amd64 /usr/local/bin/minikube
rm minikube-linux-amd64

# 6. 啟動 Minikube
echo "啟動 Minikube（使用 docker driver）與提升docker 權限"
echo "sudo usermod -aG docker $USER && newgrp docker"
echo "minikube start --driver=docker"

# 7. 驗證
echo "使用 kubectl 驗證:"
echo "kubectl get nodes"


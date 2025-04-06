#!/bin/bash

# shell: kind_setup.sh
# purpose: 安裝 Kind 並建立本機 Kubernetes 叢集

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

echo -e "${GREEN}開始安裝 Kind 環境...${NC}"

# 1. 安裝 Docker
echo "安裝 Docker..."
curl -fsSL https://get.docker.com | sh

# 2. 安裝 kubectl
echo "安裝 kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# 3. 安裝 Kind
echo "安裝 Kind..."
curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64
install -o root -g root -m 0755 kind /usr/local/bin/kind
rm kind

echo -e "${GREEN}✅ 安裝完成！${NC}"
echo
echo -e "${GREEN}👉 請使用readme指令切建立 Kind 叢集${NC}"
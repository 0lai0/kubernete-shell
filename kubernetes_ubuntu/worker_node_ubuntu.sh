#!/bin/bash

# shell: ubuntu_k8s_worker.sh
# purpose: Set up Kubernetes Worker node on local Ubuntu 22.04

# Enable error checking
set -e

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}This script must be run as root (use sudo)${NC}"
    exit 1
fi

# Verify Ubuntu system
if ! grep -qi "ubuntu" /etc/os-release; then
    echo -e "${RED}This script only supports Ubuntu systems${NC}"
    exit 1
fi

# Define variables
K8S_VERSION="1.29.2-1.1"  # Kubernetes version

echo -e "${GREEN}Starting Kubernetes Worker node setup...${NC}"

# 1. Set hostname and update /etc/hosts
echo "Configuring hostname and /etc/hosts..."
hostnamectl set-hostname k8s-worker
WORKER_IP=$(hostname -I | awk '{print $1}')
if ! grep -q "$WORKER_IP k8s-worker" /etc/hosts; then
    echo "$WORKER_IP k8s-worker" >> /etc/hosts
else
    echo "k8s-worker entry already exists in /etc/hosts, skipping..."
fi

# 2. Disable Swap
echo "Disabling Swap..."
swapoff -a
if grep -q "^[^#].*swap" /etc/fstab; then
    sed -i '/swap/ s/^/#/' /etc/fstab || { echo -e "${RED}Failed to modify /etc/fstab${NC}"; exit 1; }
fi
if free | grep -q "Swap: *[1-9]"; then
    echo -e "${RED}Swap is still active. Please check system settings${NC}"
    exit 1
fi

# 3. Install and configure Containerd
echo "Installing and configuring Containerd..."
apt-get update -y
apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y containerd.io || { echo -e "${RED}Failed to install Containerd${NC}"; exit 1; }

# Configure Containerd
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml || { echo -e "${RED}Failed to configure Containerd${NC}"; exit 1; }
systemctl restart containerd || { echo -e "${RED}Failed to restart Containerd${NC}"; exit 1; }

# 4. Enable required kernel modules and sysctl settings
echo "Configuring kernel modules and settings..."
cat <<EOF > /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
modprobe overlay || { echo -e "${RED}Failed to load overlay module${NC}"; exit 1; }
modprobe br_netfilter || { echo -e "${RED}Failed to load br_netfilter module${NC}"; exit 1; }
cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system || { echo -e "${RED}Failed to apply kernel settings${NC}"; exit 1; }

# 5. Install Kubernetes components (kubelet, kubeadm)
echo "Installing Kubernetes components..."
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg || { echo -e "${RED}Failed to install Kubernetes GPG key${NC}"; exit 1; }
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list
apt-get update -y
apt-get install -y kubelet="$K8S_VERSION" kubeadm="$K8S_VERSION" || { echo -e "${RED}Failed to install Kubernetes components${NC}"; exit 1; }
apt-mark hold kubelet kubeadm
systemctl enable --now kubelet || { echo -e "${RED}Failed to enable kubelet${NC}"; exit 1; }

# 6. Join the cluster
echo "Please enter the kubeadm join command from the master node:"
read -rp "Example: kubeadm join <MASTER_IP>:6443 --token <TOKEN> --discovery-token-ca-cert-hash sha256:<HASH> > " JOIN_CMD

# Execute the join command
eval "$JOIN_CMD" || { echo -e "${RED}Failed to join the Kubernetes cluster${NC}"; exit 1; }

echo -e "${GREEN}Worker node setup completed successfully and joined the cluster!${NC}"

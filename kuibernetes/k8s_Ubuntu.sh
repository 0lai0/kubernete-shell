#!/bin/bash

# shell: ubuntu_k8s_local.sh
# purpose: Set up Kubernetes Master node on local Ubuntu 22.04

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
POD_CIDR="10.244.0.0/16"  # Pod network CIDR
K8S_VERSION="1.29.2-1.1"  # Kubernetes version

echo -e "${GREEN}Starting Kubernetes Master node setup on local machine...${NC}"

# 1. Get Master IP (local setup)
echo "Fetching local Master IP..."
MASTER_IP=$(hostname -I | awk '{print $1}')
if [ -z "$MASTER_IP" ]; then
    echo -e "${RED}Could not detect local IP. Please enter the Master node IP manually:${NC}"
    read -r MASTER_IP
else
    echo "Detected local IP is $MASTER_IP. Use this IP? (y/n)"
    read -r confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "Please enter the Master node IP (e.g., your Tailscale IP or local IP):"
        read -r MASTER_IP
    fi
fi

# 2. Set hostname and update /etc/hosts
echo "Configuring hostname and /etc/hosts..."
hostnamectl set-hostname k8s-master
if ! grep -q "$MASTER_IP k8s-master" /etc/hosts; then
    echo "$MASTER_IP k8s-master" >> /etc/hosts
else
    echo "k8s-master entry already exists in /etc/hosts, skipping..."
fi

# 3. Disable Swap
echo "Disabling Swap..."
swapoff -a
if grep -q "^[^#].*swap" /etc/fstab; then
    sed -i '/swap/ s/^/#/' /etc/fstab || { echo -e "${RED}Failed to modify /etc/fstab${NC}"; exit 1; }
fi
if free | grep -q "Swap: *[1-9]"; then
    echo -e "${RED}Swap is still active. Please check system settings${NC}"
    exit 1
fi

# 4. Install and configure Containerd
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

# 5. Enable required kernel modules and sysctl settings
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

# 6. Install Kubernetes components
echo "Installing Kubernetes components..."
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg || { echo -e "${RED}Failed to install Kubernetes GPG key${NC}"; exit 1; }
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list
apt-get update -y
apt-get install -y kubelet="$K8S_VERSION" kubeadm="$K8S_VERSION" kubectl="$K8S_VERSION" || { echo -e "${RED}Failed to install Kubernetes components${NC}"; exit 1; }
apt-mark hold kubelet kubeadm kubectl
systemctl enable --now kubelet || { echo -e "${RED}Failed to enable kubelet${NC}"; exit 1; }

# 7. Initialize Kubernetes Master node
echo "Initializing Kubernetes Master node..."
kubeadm config images pull || { echo -e "${RED}Failed to pull Kubernetes images${NC}"; exit 1; }
kubeadm init --apiserver-advertise-address="$MASTER_IP" --pod-network-cidr="$POD_CIDR" | tee kubeadm_init.log || { echo -e "${RED}Initialization failed. Check kubeadm_init.log${NC}"; exit 1; }

# 8. Configure kubectl for root
echo "Configuring kubectl for root..."
mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config || { echo -e "${RED}Failed to copy admin.conf${NC}"; exit 1; }
chown root:root /root/.kube/config

# 9. Install Flannel CNI
echo "Installing Flannel network plugin..."
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml || { echo -e "${RED}Failed to install Flannel${NC}"; exit 1; }

# 10. Generate and save join command for worker nodes
echo "Generating join command for worker nodes..."
JOIN_CMD=$(kubeadm token create --print-join-command)
echo "$JOIN_CMD" > k8s-join-command.txt
echo -e "${GREEN}Master node setup completed successfully!${NC}"
echo "Use the command in 'k8s-join-command.txt' on worker nodes to join the cluster."
echo "Example: sudo $JOIN_CMD"
echo "kubectl is configured at /root/.kube/config. Run 'kubectl get nodes' to check node status."

# 11. Configure kubectl for the current user
echo "Configuring kubectl for the current user..."
mkdir -p "$HOME/.kube"
sudo cp /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(whoami)":"$(whoami)" "$HOME/.kube/config"
echo "kubectl configured for $(whoami). Run 'kubectl get nodes' to verify."
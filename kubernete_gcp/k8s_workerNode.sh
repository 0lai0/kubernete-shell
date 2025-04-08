#!/bin/bash

# Note: This script assumes that the user has already set up a Kubernetes Master node and has the join command ready.
# The script also assumes that the user has the necessary permissions to execute the commands and modify system files.
# The script is designed to be run on a fresh Ubuntu 22.04 VM instance
# shell: gcp_k8s_worker.sh
# using: Ubuntu 22.04 VM setting Kubernetes Worker node on GCP


# error check
set -e

# color
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# check root 
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root (sudo)${NC}"
    exit 1
fi

# check Ubuntu system
if ! grep -qi "ubuntu" /etc/os-release; then
    echo -e "${RED}This script only supports Ubuntu system${NC}"
    exit 1
fi

# define var
K8S_VERSION="1.29.2-1.1"   # Kubernetes version, consistent with Master

echo -e "${GREEN}Starting to set up Kubernetes Worker node...${NC}"

# 1. set hostname
echo "Setting hostname..."
hostnamectl set-hostname k8s-worker-$(hostname | cut -d'-' -f2-)
WORKER_IP=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip -H "Metadata-Flavor: Google")
if [ -n "$WORKER_IP" ]; then
    echo "$WORKER_IP k8s-worker-$(hostname | cut -d'-' -f2-)" >> /etc/hosts
fi

# 2. shutdown Swap
echo "Shutting down Swap..."
swapoff -a
if grep -q "^[^#].*swap" /etc/fstab; then
    sed -i '/swap/ s/^/#/' /etc/fstab || { echo -e "${RED}Failed to modify fstab${NC}"; exit 1; }
fi
if free | grep -q "Swap: *[1-9]"; then
    echo -e "${RED}Swap did not shut down, please check system settings${NC}"
    exit 1
fi

# 3. install and configure Containerd
echo "Installing and configuring Containerd..."
apt-get update -y
apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y containerd.io || { echo -e "${RED}Failed to install Containerd${NC}"; exit 1; }

# configure Containerd
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml || { echo -e "${RED}Failed to configure Containerd${NC}"; exit 1; }
systemctl restart containerd || { echo -e "${RED}Failed to restart Containerd${NC}"; exit 1; }

# 4. enable Kernel modules and variables
echo "Configuring Kernel modules and variables..."
cat <<EOF > /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
modprobe overlay || { echo -e "${RED}Failed to load overlay${NC}"; exit 1; }
modprobe br_netfilter || { echo -e "${RED}Failed to load br_netfilter${NC}"; exit 1; }
cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system || { echo -e "${RED}Failed to load Kernel variables${NC}"; exit 1; }

# 5. install Kubernetes components
echo "Installing Kubernetes components..."
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg || { echo -e "${RED}Failed to install Kubernetes GPG${NC}"; exit 1; }
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list
apt-get update -y
apt-get install -y kubelet=$K8S_VERSION kubeadm=$K8S_VERSION kubectl=$K8S_VERSION || { echo -e "${RED}Failed to install Kubernetes components${NC}"; exit 1; }
apt-mark hold kubelet kubeadm kubectl
systemctl enable --now kubelet || { echo -e "${RED}Failed to enable kubelet${NC}"; exit 1; }

# 6. join the cluster (requires join command from Master)
echo "Please provide the join command from the Master node (from k8s-join-command.txt):"
echo "Example: kubeadm join 10.0.0.1:6443 --token abcdef.1234567890abcdef --discovery-token-ca-cert-hash sha256:xxx"
read -r JOIN_CMD
if [ -z "$JOIN_CMD" ]; then
    echo -e "${RED}Join command cannot be empty${NC}"
    exit 1
fi
$JOIN_CMD || { echo -e "${RED}Failed to join cluster, please check the join command${NC}"; exit 1; }

# 7. configure kubectl for current user
echo "Configuring kubectl for current user..."
mkdir -p ~/.kube
cp /etc/kubernetes/kubelet.conf ~/.kube/config || { echo -e "${RED}Failed to copy kubelet.conf${NC}"; exit 1; }
chown $(whoami):$(whoami) ~/.kube/config
echo "You can now use 'kubectl get nodes' to check node status from this user."

echo -e "${GREEN}Worker node setup completed successfully!${NC}"
echo -e "${GREEN}You can now use 'kubectl get nodes' to check node status.${NC}"

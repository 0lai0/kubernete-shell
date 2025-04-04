#!/bin/bash

# shell: setup_k8s_master.sh
# using: Ubuntu 22.04 VM setting Kubernetes Master node on gcp

# error check
set -e

# color
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# check root 
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}using root (sudo)${NC}"
    exit 1
fi

# check Ubuntu system
if ! grep -qi "ubuntu" /etc/os-release; then
    echo -e "${RED}This shell only support Ubuntu system${NC}"
    exit 1
fi

# define var
POD_CIDR="10.244.0.0/16"  # Pod network
K8S_VERSION="1.29.2-1.1"   # Kubernetes version

echo -e "${GREEN}start seting Kubernetes Master node...${NC}"

# 1. get Master IP
echo "checking master IP..."
MASTER_IP=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip -H "Metadata-Flavor: Google")
if [ -z "$MASTER_IP" ]; then
    echo -e "${RED}could not get IP on GCP Metadata , please mannual Master node ip:${NC}"
    read -r MASTER_IP
else
    echo "ㄍdetected external IP is $MASTER_IP, sure using this IP?(y/n)"
    read -r confirm
    if [ "$confirm" != "y" ]; then
        echo "please enter Master node IP:"
        read -r MASTER_IP
    fi
fi

# 2. seting name and /etc/hosts
echo "seting name and /etc/hosts..."
hostnamectl set-hostname k8s-master
if ! grep -q "k8s-master" /etc/hosts; then
    echo "$MASTER_IP k8s-master" >> /etc/hosts
else
    echo "k8s-master is exist /etc/hosts, skip setting"
fi

# 3. shutdown Swap
echo "shutdown Swap..."
swapoff -a
if grep -q "^[^#].*swap" /etc/fstab; then
    sed -i '/swap/ s/^/#/' /etc/fstab || { echo -e "${RED}modify fstab fail${NC}"; exit 1; }
fi
if free | grep -q "Swap: *[1-9]"; then
    echo -e "${RED}Swap did not shutdown, please check system setting${NC}"
    exit 1
fi

# 4. install and setting Containerd
echo "setting Containerd..."
apt-get update -y
apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y containerd.io || { echo -e "${RED}install Containerd fail${NC}"; exit 1; }

# setting Containerd
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml || { echo -e "${RED}modify Containerd setting fail${NC}"; exit 1; }
systemctl restart containerd || { echo -e "${RED}restart Containerd fail${NC}"; exit 1; }

# 5. enable Kernel configuration and var
echo "setting Kernel configuration and var..."
cat <<EOF > /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
modprobe overlay || { echo -e "${RED}loading overlay fail${NC}"; exit 1; }
modprobe br_netfilter || { echo -e "${RED}loading br_netfilter fail${NC}"; exit 1; }
cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system || { echo -e "${RED}loading Kernel varible fail${NC}"; exit 1; }

# 6. install Kubernetes extension
echo "install Kubernetes extension..."
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg || { echo -e "${RED}install Kubernetes GPG fail${NC}"; exit 1; }
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list
apt-get update -y
apt-get install -y kubelet=$K8S_VERSION kubeadm=$K8S_VERSION kubectl=$K8S_VERSION || { echo -e "${RED}install Kubernetes extension fail${NC}"; exit 1; }
apt-mark hold kubelet kubeadm kubectl
systemctl enable --now kubelet || { echo -e "${RED}start up kubelet fail${NC}"; exit 1; }

# 7. initialize Kubernetes Master node
echo "initialize Kubernetes Master node..."
kubeadm config images pull || { echo -e "${RED}pulling Kubernetes mirror fail${NC}"; exit 1; }
kubeadm init --apiserver-advertise-address="$MASTER_IP" --pod-network-cidr="$POD_CIDR" | tee kubeadm_init.log || { echo -e "${RED}initialize fail, please check kubeadm_init.log${NC}"; exit 1; }

# 8. setting kubectl
echo "setting kubectl Administrator..."
mkdir -p /root/.kube || { echo -e "${RED}create .kube list fail${NC}"; exit 1; }
cp -i /etc/kubernetes/admin.conf /root/.kube/config || { echo -e "${RED}copy admin.conf fail${NC}"; exit 1; }
chown root:root /root/.kube/config

# 9. install Flannel network extension
echo "install Flannel network extension..."
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml || { echo -e "${RED}install Flannel fail${NC}"; exit 1; }

# 10. create and store Worker node and add to command
echo "create and store Worker node and add to command..."
JOIN_CMD=$(kubeadm token create --print-join-command)
echo "$JOIN_CMD" > k8s-join-command.txt
echo -e "${GREEN}Master node initialize successful!${NC}"
echo "please use 'k8s-join-command.txt' copy to every Worker node to excute, and add to cluster"
echo "example: sudo $JOIN_CMD"
echo "kubectl configure in /root/.kube/config, you can use 'kubectl get nodes' to check node status。"
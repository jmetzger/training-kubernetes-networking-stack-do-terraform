#!/bin/bash
set -e
K8S_VERSION="1.33.0-00"
FALLBACK_VERSION="1.32.3-00"

# Prüfen, ob K8S_VERSION verfügbar ist
if ! apt-cache madison kubeadm | grep -q "$K8S_VERSION"; then
  echo "[WARN] Kubernetes-Version $K8S_VERSION ist nicht verfügbar."
  echo "[INFO] Fallback auf Version $FALLBACK_VERSION"
  K8S_VERSION="$FALLBACK_VERSION"

  if ! apt-cache madison kubeadm | grep -q "$K8S_VERSION"; then
    echo "[ERROR] Auch die Fallback-Version $FALLBACK_VERSION ist nicht verfügbar."
    echo "Verfügbare Versionen:"
    apt-cache madison kubeadm
    exit 1
  fi
fi

# Disable swap
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# Install basic tools
apt-get update && apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  software-properties-common

# Install containerd
apt-get install -y containerd
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# Add Kubernetes repo
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet=${K8S_VERSION} kubeadm=${K8S_VERSION} kubectl=${K8S_VERSION}
apt-mark hold kubelet kubeadm kubectl

# Enable net.bridge bridge-nf-call-iptables
modprobe br_netfilter
echo "net.bridge.bridge-nf-call-iptables = 1" >> /etc/sysctl.conf
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p

# Log installed versions
echo "--- Installed Kubernetes Versions ---" > /var/log/k8s-setup.log
kubelet --version >> /var/log/k8s-setup.log
kubeadm version -o short >> /var/log/k8s-setup.log
kubectl version --client -o json | jq -r '.clientVersion.gitVersion' >> /var/log/k8s-setup.log
cat /var/log/k8s-setup.log

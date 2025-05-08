#!/bin/bash
set -e

KEY="id_rsa_k8s_do"
CP_IP=$(terraform output -raw droplet_ips | head -n1)
WORKERS=$(terraform output -json droplet_ips | jq -r '.[1:][]')

echo "[INFO] Initializing control plane on $CP_IP..."
ssh -o StrictHostKeyChecking=no -i $KEY root@$CP_IP <<EOF
kubeadm init --pod-network-cidr=192.168.0.0/16
mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config

# Install Calico via Tigera Operator
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/tigera-operator.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/custom-resources.yaml
EOF

echo "[INFO] Getting join command..."
JOIN_CMD=$(ssh -i $KEY root@$CP_IP "kubeadm token create --print-join-command")

for ip in $WORKERS; do
  echo "[INFO] Joining worker $ip..."
  ssh -o StrictHostKeyChecking=no -i $KEY root@$ip "$JOIN_CMD"
done

# Lokale kubeconfig kopieren
mkdir -p ~/.kube
scp -o StrictHostKeyChecking=no -i $KEY root@$CP_IP:/etc/kubernetes/admin.conf ~/.kube/config
chmod 600 ~/.kube/config

echo "[INFO] kubeconfig wurde unter ~/.kube/config gespeichert"

# Teste kubectl Zugriff
if kubectl version --client &>/dev/null && kubectl get nodes &>/dev/null; then
  echo "[SUCCESS] kubectl Zugriff auf Cluster funktioniert."
else
  echo "[ERROR] kubectl Zugriff fehlgeschlagen. Bitte Konfiguration prüfen."
  exit 1
fi

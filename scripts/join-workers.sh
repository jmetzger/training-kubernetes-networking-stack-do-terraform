#!/bin/bash
set -e

KEY="id_rsa_k8s_do"
# Input: Kommagetrennte IPs
IFS=',' read -r -a NODE_IPS <<< "$1"
echo  "NODE_IPS"$NODE_IPS


#CP_IP_PRIVATE="$NODE_IPS_PRIVATE[0]}"
CP_IP_PRIVATE=$2
CP_IP="${NODE_IPS[0]}"
echo "CP_IP"$CP_IP"<--"
echo "CP_IP_PRIVATE"$CP_IP_PRIVATE

WORKERS=("${NODE_IPS[@]:1}")  # Alles außer dem ersten Element

echo "[INFO] Initializing control plane on $CP_IP..."
ssh -o StrictHostKeyChecking=no -i $KEY root@$CP_IP <<EOF

#kubeadm init --pod-network-cidr=192.168.0.0/16 --apiserver-advertise-address=$CP_IP_PRIVATE --config=tmp_init_config.yaml

cat << CONFIG > tmp_init_config.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
nodeRegistration:
  kubeletExtraArgs:
    node-ip: "$CP_IP_PRIVATE"
localAPIEndpoint:
  advertiseAddress: "$CP_IP_PRIVATE"  # <== private IP des Control Planes
  bindPort: 6443
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: "v1.32.0"
networking:
  podSubnet: "192.168.0.0/16"  # z. B. für Flannel
CONFIG

kubeadm init --config=tmp_init_config.yaml
mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config

# Install Calico via Tigera Operator
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/tigera-operator.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/custom-resources.yaml
EOF

echo "[INFO] Getting join command..."
JOIN_CMD=$(ssh -i $KEY root@$CP_IP "kubeadm token create --print-join-command")
TOKEN=$(ssh -i $KEY root@$CP_IP "kubeadm token list | awk 'NR==2 {print \$1}'")
DISCOVERY_HASH=$(ssh -i $KEY root@$CP_IP "openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt \
  | openssl rsa -pubin -outform DER 2>/dev/null \
  | sha256sum | awk '{print \"sha256:\" \$1}'")

echo "[INFO] Join command is $JOIN_CMD"

for ip in "${WORKERS[@]}"; do
  echo "[INFO] Joining worker $ip..."
  # ssh -o StrictHostKeyChecking=no -i $KEY root@$ip "$JOIN_CMD"
  ssh -o StrictHostKeyChecking=no -i $KEY root@$ip <<EOF

cat <<JOIN > tmp_join_config.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: JoinConfiguration
discovery:
  bootstrapToken:
    token: $TOKEN
    apiServerEndpoint: $CP_IP_PRIVATE:6443
    caCertHashes:
      - "$DISCOVERY_HASH"
nodeRegistration:
  kubeletExtraArgs:
    node-ip: $ip
JOIN

kubeadm join --config tmp_join_config.yaml

EOF
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

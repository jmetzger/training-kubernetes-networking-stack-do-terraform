#!/bin/bash 

mkdir -p ~/.kube

if [ -f ~/.kube/config ]
then
  echo "Kubeconfig exists. Giving Up"
  exit 0
fi

cat << EOF > ~/.kube/config 
apiVersion: v1
kind: Config
clusters:
- name: dummy
  cluster:
    server: https://0.0.0.0  # Unreachable fake API endpoint
    insecure-skip-tls-verify: true
contexts:
- name: dummy
  context:
    cluster: dummy
    user: dummy
current-context: dummy
users:
- name: dummy
  user:
    token: dummy-token
EOF

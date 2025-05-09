#!/bin/bash

echo "Script runs here "$(pwd)


# Needs to get executed from terraform !!! 
INGRESS_NAMESPACE=ingress-nginx
INGRESS_SERVICE_NAME=ingress-nginx-controller

# Script is started from Root-Folder, so metallb-values.yaml can be found
# That one is created by terraform 
helm repo add metallb https://metallb.github.io/metallb
helm upgrade --install --wait metallb metallb/metallb --version=0.13.12 --namespace metallb-system --create-namespace
# Now install the config 
helm upgrade --install metallb-config ./charts/metallb-config --namespace metallb-system -f metallb-values.yaml

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx --version 4.10.0 --create-namespace --namespace ingress-nginx 

# Waiting till we get an ip

while true; do
  IP=$(kubectl get svc "$INGRESS_SERVICE_NAME" -n "$INGRESS_NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  if [[ -n "$IP" ]]; then
    echo "$IP"
    # it needs to be json format
    echo "{\"ingress_ip\":\"$IP\"}" > ingress_ip.txt
    break
  fi
  sleep 5
done



#!/bin/bash

# Ensure the script stops if any command fails (optional but recommended for debugging)
set -e

# Check if the correct number of arguments are passed (host and organisationname)
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <host> <organisationname>"
    exit 1
fi

# Assign command-line arguments to variables
HOST=$1
ORG_NAME=$2

# check for prereqs
# check for git 
command -v git >/dev/null 2>&1 || { echo >&2 "I require git but it's not installed.  Aborting."; exit 1; }
command -v yq >/dev/null 2>&1 || { echo >&2 "I require yq but it's not installed.  Aborting."; exit 1; }
command -v helm >/dev/null 2>&1 || { echo >&2 "I require helm but it's not installed.  Aborting."; exit 1; }


# Install K3s
echo "Installing K3s..."
curl -sfL https://get.k3s.io | sh -
sleep 30s

# Wait for K3s to be fully ready
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
echo "Waiting for K3s node to become ready..."

# Wait for K3s node to be in "Ready" state
until sudo kubectl get nodes | grep -q "Ready"; do
    echo "Waiting for node to be ready..."
    sleep 5
done

# Print a confirmation once the node is in Ready state
echo "K3s node is in Ready state."

# Set coordonates for Kubernetes access
sudo cp /etc/rancher/k3s/k3s.yaml k3s.yaml
sudo chown $(whoami) k3s.yaml
export KUBECONFIG=`pwd`/k3s.yaml
kubectl get ns ssd || err_code=$?
if [ $err_code!=0 ]; then 
   kubectl create ns ssd
fi

# Define the path to the values.yaml file
curl -o ssd-minimal-values.yaml https://raw.githubusercontent.com/OpsMx/enterprise-ssd/2025-01/charts/ssd/ssd-minimal-values.yaml
VALUES_FILE="ssd-minimal-values.yaml"

#
# Add your custom Helm repository
echo "Adding custom Helm repository for SSD..."
helm repo add opsmxssd https://opsmx.github.io/enterprise-ssd/
helm repo update

# Use yq to modify the values.yaml file dynamically based on the command-line arguments
echo "Modifying values.yaml with host ($HOST) and organisationname ($ORG_NAME) parameters..."
yq eval -i ".global.ssdUI.host = \"$HOST\" | .organisationname = \"$ORG_NAME\"" "$VALUES_FILE"
yq eval -i ".global.certManager.installed = false" "$VALUES_FILE" 
yq eval -i ".global.createIngress = false" "$VALUES_FILE" 


# Install SSD with the modified values.yaml
echo "Installing SSD with the modified values.yaml..."
helm install ssd opsmxssd/ssd -f "$VALUES_FILE" -n ssd --timeout=600s
echo "SSD installation complete."

echo "Applying ingress rules"
curl -o ssd-ingress.yaml https://raw.githubusercontent.com/OpsMx/enterprise-ssd/2025-01/vm-install/ssd-ingress.yaml
sed -i -e s/SSD-DNS-VALUE/$HOST/ ssd-ingress.yaml
kubectl -n ssd apply -f ssd-ingress.yaml

echo "Applying ingress ports"
curl -o patch-traefik-svc.yaml https://raw.githubusercontent.com/OpsMx/enterprise-ssd/2025-01/vm-install/patch-traefik-svc.yaml
#kubectl -n kube-system patch svc traefik --type=merge --patch-file patch-traefik-svc.yaml

#Patch the system for adhoc scanning of .Net code
kubectl set image deployment/supplychain-preprocessor supplychain-preprocessor=docker.io/opsmx11/supplychain-preprocessor:c50641e-87 -n ssd
kubectl set image deployment/ssd-opa ssd-opa=docker.io/opsmx11/ssd-opa:c9bde07-115 -n ssd

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
echo "set kubeconfig path using following command"
echo "${GREEN} export KUBECONFIG=`pwd`/k3s.yaml ${NC}"

echo "Script execution complete."



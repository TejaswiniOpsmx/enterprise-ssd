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
command -v git >/dev/null 2>&1 || {
  echo >&2 "I require git but it's not installed.  Aborting."
  exit 1
}
command -v yq >/dev/null 2>&1 || {
  echo >&2 "I require yq but it's not installed.  Aborting."
  exit 1
}
command -v helm >/dev/null 2>&1 || {
  echo >&2 "I require helm but it's not installed.  Aborting."
  exit 1
}

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
export KUBECONFIG=$(pwd)/k3s.yaml
kubectl get ns ssd || err_code=$?
if [ $err_code!=0 ]; then
  kubectl create ns ssd
fi

# Define the path to the values.yaml file
VALUES_FILE="$HOME/opsmxssd/ssd-minimal-values.yaml"

# Cloning the Helm repository
#echo "Cloning the Helm repository for SSD..."
git clone https://github.com/opsmx/enterprise-ssd.git -b 2025-05
#helm repo add opsmxssd https://opsmx.github.io/enterprise-ssd/
#helm repo update

# Use yq to modify the values.yaml file dynamically based on the command-line arguments
echo "Modifying values.yaml with host ($HOST) and organisationname ($ORG_NAME) parameters..."
yq e '.' "$VALUES_FILE" >/dev/null || {
  echo "❌ yq cannot read $VALUES_FILE"
  exit 1
}

# We override the values provided in ssd-minimal-values with the values supplied in arguments
yq eval -i ".global.ssdUI.host = \"${HOST}\" | .organisationname = \"${ORG_NAME}\"" "$VALUES_FILE"
yq eval -i ".global.certManager.installed = true" "$VALUES_FILE"
yq eval -i ".global.createIngress = true" "$VALUES_FILE"

# Install OpsMx SSD with the modified values.yaml
echo "Installing OpsMx SSD with the modified values.yaml..."
helm install ssd enterprise-ssd/charts/ssd/ -f $VALUES_FILE -f enterprise-ssd/charts/ssd/rc-images-values.yaml -n ssd -n ssd --timeout=600s
echo "SSD installation complete."

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
echo "set kubeconfig path using following command"
echo "${GREEN} export KUBECONFIG=$(pwd)/k3s.yaml ${NC}"

echo "Installation complete."

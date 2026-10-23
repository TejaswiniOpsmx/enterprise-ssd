#!/bin/bash

# Check if the correct number of arguments are passed (host and organisationname)
if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <host> <organisationname> <optional initial-values file URL>"
  exit 1
fi

# Assign command-line arguments to variables
DOMAIN=$1
ORG=$2

INSTALL_SCRIPT="$HOME/opsmxssd/install.sh"
TARGET_FILE="$HOME/opsmxssd/ssd-minimal-values.yaml"
FALLBACK_FILE="$HOME/opsmxssd/default-ssd-minimal-values.yaml"
if [ "$#" -gt 2 ]; then
  REMOTE_URL=$3
  echo "Attempting to download values file from $REMOTE_URL"

  if curl -fsSL "$REMOTE_URL" -o "$TARGET_FILE"; then
    echo "Successfully downloaded values file to $TARGET_FILE"
  else
    echo "Failed to download values file. Using fallback: $FALLBACK_FILE"
    cp "$FALLBACK_FILE" "$TARGET_FILE"
    echo "Fallback values copied to $TARGET_FILE"
  fi
else
  cp "$FALLBACK_FILE" "$TARGET_FILE"
  echo "Default values copied to $TARGET_FILE"
fi

if [ ! -f "$INSTALL_SCRIPT" ]; then
  echo "Install script not found at $INSTALL_SCRIPT"
  exit 1
fi

if [ ! -f "$TARGET_FILE" ]; then
  echo "Values file not found at $TARGET_FILE"
  exit 1
fi

sudo apt-get update

sudo systemctl enable k3s
sudo systemctl start k3s
echo "Waiting for all kube-system pods to be ready..."
sudo k3s kubectl wait --for=condition=Ready pods --all -n kube-system --timeout=120s

# Ensure it's executable
chmod +x "$INSTALL_SCRIPT"
echo "Running install script: $INSTALL_SCRIPT"
bash "$INSTALL_SCRIPT" "$DOMAIN" "$ORG"
STATUS=$?
if [ $STATUS -eq 0 ]; then
  echo "Install script completed successfully."
else
  echo "Install script exited with status $STATUS"
  exit $STATUS
fi

echo "Waiting for all ssd pods to be ready..."
sudo k3s kubectl wait --for=condition=Ready pods --all -n ssd --timeout=60s
sudo kubectl get pods -n ssd
ADMIN_PASS=$(sudo kubectl get secret -n ssd ssd-initial-password -o jsonpath="{.data.ADMIN_PASSWORD}" | base64 --decode)

echo "Initial login credentials:"
echo "  URL: https://$DOMAIN"
echo "  Username: admin"
echo "  Password: $ADMIN_PASS"

echo "SSD was set-up completed successfully"

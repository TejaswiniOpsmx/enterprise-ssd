#!/bin/bash

# Extract IP and DOMAIN from the ingress
IP=$(sudo kubectl get ingress ssd-ui-ingress -n ssd \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

DOMAIN=$(sudo kubectl get ingress ssd-ui-ingress -n ssd \
  -o jsonpath='{.spec.rules[0].host}')

HOSTS_FILE="/etc/hosts"

if [[ -z "$IP" || -z "$DOMAIN" ]]; then
  echo "Failed to retrieve IP or domain from ingress."
  exit 1
fi

# Check if the entry already exists
if grep -qE "^\s*${IP}\s+.*\b${DOMAIN}\b" "$HOSTS_FILE"; then
  echo "Entry already exists: $IP $DOMAIN"
else
  echo "Adding entry: $IP $DOMAIN"
  echo -e "$IP\t$DOMAIN" | sudo tee -a "$HOSTS_FILE" >/dev/null
  echo "Done."
fi

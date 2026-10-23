#!/bin/bash

sudo kubectl annotate certificate ssd-ui-ingress -n ssd cert-manager.io/renew-request-at="$(date -u +%Y-%m-%dT%H:%M:%SZ)" --overwrite

echo "Cert-manager triggered to fetch new ssl certificate"

echo "To view cert-manager logs, run:"
echo "  sudo kubectl logs -n cert-manager -l app=cert-manager --tail=50 --follow"

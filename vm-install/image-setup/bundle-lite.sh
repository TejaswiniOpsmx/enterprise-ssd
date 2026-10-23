#!/bin/bash
set -e

VERSION_FILE="./version.env"

if [[ -f "$VERSION_FILE" ]]; then
  source "$VERSION_FILE"
else
  echo "[ERROR] version.env file not found. Aborting."
  exit 1
fi

# Optional overrides from CLI arguments
[[ -n "$1" ]] && CHARTVERSION="$1"
[[ -n "$2" ]] && RELEASETAG="$2"

echo "Using CHARTVERSION=$CHARTVERSION"
echo "Using RELEASETAG=$RELEASETAG"

sudo apt-get update
sudo apt install -y docker.io
sudo apt install -y git
sudo snap install helm --classic
sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 \
  -O /usr/local/bin/yq
sudo chmod 755 /usr/local/bin/yq

echo "starting docker..."
sudo systemctl enable docker
sudo systemctl start docker

mkdir -p opsmxssd

curl -fSL -o opsmxssd/default-ssd-minimal-values.yaml https://raw.githubusercontent.com/OpsMx/enterprise-ssd/$RELEASETAG/charts/ssd/ssd-minimal-values.yaml
curl -fSL -o opsmxssd/bootstrap.sh https://raw.githubusercontent.com/OpsMx/enterprise-ssd/$RELEASETAG/vm-install/image-setup/bootstrap-lite.sh
curl -fSL -o opsmxssd/install.sh https://raw.githubusercontent.com/OpsMx/enterprise-ssd/$RELEASETAG/vm-install/image-setup/install.sh
curl -fSL -o opsmxssd/add-dns-entry-in-local.sh https://raw.githubusercontent.com/OpsMx/enterprise-ssd/$RELEASETAG/vm-install/image-setup/add-dns-entry-in-local.sh
curl -fSL -o opsmxssd/fetch-ssl-cert.sh https://raw.githubusercontent.com/OpsMx/enterprise-ssd/$RELEASETAG/vm-install/image-setup/fetch-ssl-cert.sh

chmod +x opsmxssd/bootstrap.sh
chmod +x opsmxssd/install.sh
chmod +x opsmxssd/add-dns-entry-in-local.sh
chmod +x opsmxssd/fetch-ssl-cert.sh

# Replace CHARTVERSION in install.sh with actual value
sed -i "s/--version CHARTVERSION/--version ${CHARTVERSION}/" opsmxssd/install.sh

helm repo add opsmxssd https://opsmx.github.io/enterprise-ssd/
helm repo update

echo "installing k3s..."
# Install k3s (in Docker mode for image reuse)
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--node-name=ssd-primary --docker --disable=traefik" sh -

pwd
echo "loading the images from tar files into docker.."
IMAGES_DIR="/opt/opsmx/temp-images"
ls $IMAGES_DIR
for tarfile in "$IMAGES_DIR"/*.tar; do
  echo "Loading image from $tarfile"
  sudo docker load -i "$tarfile"
  echo "deleting $tarfile"
  sudo rm $tarfile
done
echo "all images loaded from $IMAGES_DIR"

echo "ensuring k3s has started..."
sudo k3s kubectl wait --for=condition=Ready nodes --all --timeout=90s
sudo k3s kubectl get nodes

# Set coordonates for Kubernetes access
sudo cp /etc/rancher/k3s/k3s.yaml k3s.yaml
sudo chown $(whoami) k3s.yaml
export KUBECONFIG=$(pwd)/k3s.yaml

echo "instaling ingress and cert-manager..."
# Set up kubeconfig and install nginx ingress and cert-manager
# below commands are clubbed and run as root user
helm repo add jetstack https://charts.jetstack.io
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
if helm status cert-manager -n cert-manager &>/dev/null; then
  echo "cert-manager already installed. Skipping install."
else
  echo "Installing cert-manager"
  helm install cert-manager jetstack/cert-manager \
    --namespace cert-manager --create-namespace --set installCRDs=true --wait
fi

if helm status ingress-nginx -n ingress-nginx &>/dev/null; then
  echo "ingress-nginx already installed. Skipping install."
else
  echo "Installing ingress-nginx"
  helm install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace ingress-nginx --create-namespace --wait
fi

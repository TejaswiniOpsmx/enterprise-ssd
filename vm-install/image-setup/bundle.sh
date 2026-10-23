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
echo "Using RELEASETAG=2025-05"

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

curl -fSL -o opsmxssd/default-ssd-minimal-values.yaml https://raw.githubusercontent.com/OpsMx/enterprise-ssd/2025-05/charts/ssd/ssd-minimal-values.yaml
curl -fSL -o opsmxssd/bootstrap.sh https://raw.githubusercontent.com/OpsMx/enterprise-ssd/2025-05/vm-install/image-setup/bootstrap.sh
curl -fSL -o opsmxssd/install.sh https://raw.githubusercontent.com/OpsMx/enterprise-ssd/2025-05/vm-install/image-setup/install.sh
curl -fSL -o opsmxssd/add-dns-entry-in-local.sh https://raw.githubusercontent.com/OpsMx/enterprise-ssd/2025-05/vm-install/image-setup/add-dns-entry-in-local.sh
curl -fSL -o opsmxssd/fetch-ssl-cert.sh https://raw.githubusercontent.com/OpsMx/enterprise-ssd/2025-05/vm-install/image-setup/fetch-ssl-cert.sh
curl -fSL -o extract-images-list.sh https://raw.githubusercontent.com/OpsMx/enterprise-ssd/2025-05/vm-install/image-setup/extract-images-list.sh
curl -fSL -o pull-images.sh https://raw.githubusercontent.com/OpsMx/enterprise-ssd/2025-05/vm-install/image-setup/pull-images.sh
curl -fSL -o clean-before-build.sh https://raw.githubusercontent.com/OpsMx/enterprise-ssd/2025-05/vm-install/image-setup/clean-before-build.sh

chmod +x opsmxssd/bootstrap.sh
chmod +x opsmxssd/install.sh
chmod +x opsmxssd/add-dns-entry-in-local.sh
chmod +x opsmxssd/fetch-ssl-cert.sh
chmod +x extract-images-list.sh
chmod +x pull-images.sh
chmod +x clean-before-build.sh

# Replace CHARTVERSION in install.sh with actual value
#sed -i "s/--version CHARTVERSION/--version ${CHARTVERSION}/" opsmxssd/install.sh

git clone https://github.com/opsmx/enterprise-ssd.git -b 2025-05
#helm repo add opsmxssd https://opsmx.github.io/enterprise-ssd/
#helm repo update

# dry run of helm install
helm template ssd enterprise-ssd/charts/ssd/ -f enterprise-ssd/charts/ssd/ssd-minimal-values.yaml -f enterprise-ssd/charts/ssd/rc-images-values.yaml -n ssd >rendered.yaml
#helm template opsmxssd opsmxssd/ssd --version $CHARTVERSION >rendered.yaml

./extract-images-list.sh rendered.yaml image-list.txt

cat image-list.txt

echo "installing k3s..."
# Install k3s (in Docker mode for image reuse)
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--node-name=ssd-primary --docker --disable=traefik" sh -

echo "pulling the images and caching it in docker..."
./pull-images.sh image-list.txt

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
  helm install ingress-nginx ingress-nginx/ingress-nginx --version=4.12.1 \
	--namespace ingress-nginx \
	--create-namespace \
	--set controller.progressDeadlineSeconds=120 \
	--set controller.minReadySeconds=10
fi

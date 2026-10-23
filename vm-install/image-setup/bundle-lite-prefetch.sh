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

helm repo add opsmxssd https://opsmx.github.io/enterprise-ssd/
helm repo update

# dry run of helm install
helm template opsmxssd opsmxssd/ssd --version $CHARTVERSION >rendered.yaml

chmod +x extract-images-list.sh

./extract-images-list.sh rendered.yaml image-list.txt

cat image-list.txt

normalize_name() {
  echo "$1" | sed 's/[\/:]/_/g'
}

echo "pulling the images and saving it as tar file..."
IMAGES_DIR="./images"
export IMAGES_DIR
mkdir -p "$IMAGES_DIR"
while IFS= read -r image; do
  if [ -z "$image" ]; then continue; fi

  echo "Pulling $image..."
  sudo docker pull "$image"

  filename="$(normalize_name "$image").tar"
  echo "Saving $image as $filename"
  sudo docker save -o "$IMAGES_DIR/$filename" "$image"

done <"image-list.txt"

sudo chmod 644 $IMAGES_DIR/*.tar
sudo chmod +x $IMAGES_DIR

echo "all images saved in $IMAGES_DIR"

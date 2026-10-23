#!/bin/bash
set -e

# This can be Release tag (recommended) or a branch name

sudo apt update
sudo apt install -y unzip curl
sudo apt install -y gvncviewer

# Download the latest Packer binary
PACKER_VERSION="1.12.0"
curl -fSL -o packer.zip "https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip"

# Unzip and move to /usr/local/bin
unzip packer.zip
sudo mv packer /usr/local/bin/
packer --version # confirm install
packer plugins install github.com/hashicorp/qemu
sudo apt install -y qemu-system-x86 qemu-utils
sudo apt install xorriso -y

curl -fSL -o bundle-lite-prefetch.sh https://raw.githubusercontent.com/OpsMx/enterprise-ssd/$RELEASETAG/vm-install/image-setup/bundle-lite-prefetch.sh

curl -fSL -o extract-images-list.sh https://raw.githubusercontent.com/OpsMx/enterprise-ssd/$RELEASETAG/vm-install/image-setup/extract-images-list.sh

curl -fSL -o version.env https://raw.githubusercontent.com/OpsMx/enterprise-ssd/$RELEASETAG/vm-install/image-setup/version.env

curl -fSL -o user-data.tpl https://raw.githubusercontent.com/OpsMx/enterprise-ssd/$RELEASETAG/vm-install/packer/user-data.tpl

curl -fSL -o meta-data https://raw.githubusercontent.com/OpsMx/enterprise-ssd/$RELEASETAG/vm-install/packer/meta-data

curl -fSL -o network-config https://raw.githubusercontent.com/OpsMx/enterprise-ssd/$RELEASETAG/vm-install/packer/network-config

curl -fSL -o ssd-ubuntu.pkr.hcl https://raw.githubusercontent.com/OpsMx/enterprise-ssd/$RELEASETAG/vm-install/packer/ssd-ubuntu.pkr.hcl

curl -fSL -o ssd-ubuntu.pkrvars.hcl https://raw.githubusercontent.com/OpsMx/enterprise-ssd/$RELEASETAG/vm-install/packer/ssd-ubuntu.pkrvars.hcl

# 🔧 Render cloud-init config from template
envsubst '${RELEASETAG}' <user-data.tpl >user-data
echo "✅ Rendered user-data with RELEASETAG=$RELEASETAG"

# (when not dealing with version tags) Update release tag in version.env with what value is in enviornment variable
sed -i "s/^RELEASETAG=.*/RELEASETAG=${RELEASETAG}/" version.env

chmod +x bundle-lite-prefetch.sh
./bundle-lite-prefetch.sh

#IMG="jammy-server-cloudimg-amd64.img"
#IMG_URL="https://cloud-images.ubuntu.com/jammy/current/$IMG"
#CHECKSUM=$(curl -s https://cloud-images.ubuntu.com/jammy/current/SHA256SUMS | grep "$IMG" | awk '{print $1}')

## Inject checksum into a Packer HCL file template
#envsubst <<EOF > ssd-ubuntu.pkrvars.hcl
#iso_url = "$IMG_URL"
#iso_checksum = "sha256:$CHECKSUM"
#EOF

packer init .
PACKER_LOG=1 packer build -var-file=ssd-ubuntu.pkrvars.hcl .

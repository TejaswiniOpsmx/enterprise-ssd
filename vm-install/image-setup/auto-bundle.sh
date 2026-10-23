#!/bin/bash
set -e

# This can be Release tag (recommended) or a branch name
RELEASETAG=ami_image_creation_v1

curl -fSL -o bundle.sh https://raw.githubusercontent.com/OpsMx/enterprise-ssd/$RELEASETAG/vm-install/image-setup/bundle.sh

curl -fSL -o version.env https://raw.githubusercontent.com/OpsMx/enterprise-ssd/$RELEASETAG/vm-install/image-setup/version.env

# Make the downloaded script as executable
chmod +x bundle.sh

# (when not dealing with version tags) Update release tag in version.env with what value is in enviornment variable
sed -i "s/^RELEASETAG=.*/RELEASETAG=${RELEASETAG}/" version.env

# Run the bundle.sh
./bundle.sh

# Check if all images are pulled
sudo docker images

# Clean the script files used for bundling
./clean-before-build.sh

# Clean cloud-init and shutdown the instance
sudo cloud-init clean
# Shutdown after this manually or use the below command
#sudo shutdown -h now

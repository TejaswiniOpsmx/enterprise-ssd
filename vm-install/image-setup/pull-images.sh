#!/bin/bash

# Usage: ./pull-images.sh image-list.txt

IMAGE_LIST="$1"

if [ -z "$IMAGE_LIST" ]; then
  echo "Usage: $0 <image-list.txt>"
  exit 1
fi

while IFS= read -r image; do
  if [ -z "$image" ]; then continue; fi

  echo "Pulling $image..."
  sudo docker pull "$image"

done <"$IMAGE_LIST"

echo "All images pulled and cached by docker"

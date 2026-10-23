#!/bin/bash

# Usage: ./extract-images-list.sh rendered.yaml [output.txt]

RENDERED_YAML="$1"
OUTPUT_FILE="${2:-image-list.txt}"

if [ -z "$RENDERED_YAML" ]; then
  echo "Usage: $0 <rendered.yaml> [output_file]"
  exit 1
fi

python3 - <<EOF
import sys
import yaml
from pathlib import Path

file = Path("$RENDERED_YAML")
if not file.exists():
    print(f"File not found: {file}")
    sys.exit(1)

docs = list(yaml.safe_load_all(file.read_text()))
images = set()

def scan(obj):
    if isinstance(obj, dict):
        if "image" in obj and isinstance(obj["image"], str):
            images.add(obj["image"])
        elif "image" in obj and isinstance(obj["image"], dict):
            repo = obj["image"].get("repository")
            tag = obj["image"].get("tag")
            if repo and tag:
                images.add(f"{repo}:{tag}")
            elif repo:
                images.add(repo)
        for value in obj.values():
            scan(value)
    elif isinstance(obj, list):
        for item in obj:
            scan(item)

for doc in docs:
    scan(doc)

with open("$OUTPUT_FILE", "w") as out:
    for image in sorted(images):
        out.write(f"{image}\n")

print(f"✅ Extracted {len(images)} images into: $OUTPUT_FILE")
EOF

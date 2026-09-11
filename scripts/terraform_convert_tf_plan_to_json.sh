#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f ./terraform.tfplan ]]; then
  echo "terraform.tfplan not found in $(pwd)"
  exit 1
fi

terraform show -json ./terraform.tfplan > ./terraform.json
echo "Wrote terraform.json"

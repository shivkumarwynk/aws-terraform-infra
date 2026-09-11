#!/usr/bin/env bash
set -euo pipefail

# Validate a terraform show -json plan file (terraform.json) before apply.

if [[ ! -f terraform.json ]]; then
  echo "terraform.json not found; run terraform plan and convert it first."
  exit 1
fi

terraform validate -no-color

if ! python3 - "${PWD}/terraform.json" <<'PY'
import json
import sys

path = sys.argv[1]
try:
    with open(path, encoding="utf-8") as handle:
        plan = json.load(handle)
except json.JSONDecodeError as exc:
    print(f"terraform.json is not valid JSON: {exc}")
    sys.exit(1)

if not isinstance(plan, dict) or "format_version" not in plan:
    print("terraform.json does not look like a terraform show -json plan")
    sys.exit(1)

errored = plan.get("errored")
if errored:
    print("Terraform plan is in an errored state; not proceeding")
    sys.exit(1)

print("Terraform plan JSON is valid; no AWS plan errors detected")
PY
then
  echo "Terraform plan validation failed; not proceeding"
  exit 1
fi

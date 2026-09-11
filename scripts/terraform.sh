#!/usr/bin/env bash
set -euo pipefail

# Run Terraform against one or more working directories using AWS credentials
# selected from the top-level account folder (enterprise, airtel, wynk, ...).
#
# Usage:
#   terraform.sh <plan|apply|validate> [branch]
#   terraform.sh [branch]                 # main/master -> apply, otherwise plan
#
# Locations:
#   MANUAL_LOCATION   single directory (e.g. enterprise/ec2)
#   otherwise         scripts/locations.txt (one directory per line)
#
# Credentials (per stack; account-prefixed vars always win for that folder):
#   1. <ACCOUNT>_AWS_ACCESS_KEY_ID and <ACCOUNT>_AWS_SECRET_ACCESS_KEY
#      e.g. ENTERPRISE_AWS_ACCESS_KEY_ID for folder enterprise/
#   2. Otherwise the original AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY
#   Region: <ACCOUNT>_AWS_REGION, else original AWS_REGION, else ap-south-1

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCATIONS_FILE="${REPO_ROOT}/scripts/locations.txt"
GENERIC_AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-}"
GENERIC_AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-}"
GENERIC_AWS_REGION="${AWS_DEFAULT_REGION:-${AWS_REGION:-ap-south-1}}"

COMMAND="${1:-}"
BRANCH="${2:-${GITHUB_REF_NAME:-}}"

if [[ "${COMMAND}" != "plan" && "${COMMAND}" != "apply" && "${COMMAND}" != "validate" ]]; then
  BRANCH="${COMMAND}"
  if [[ "${BRANCH}" == "main" || "${BRANCH}" == "master" ]]; then
    COMMAND="apply"
  else
    COMMAND="plan"
  fi
fi

account_prefix() {
  echo "$1" | tr '[:lower:]' '[:upper:]' | tr '-' '_'
}

set_aws_credentials_for_location() {
  local location="$1"
  local account prefix key_var secret_var region_var
  account="${location%%/*}"
  prefix="$(account_prefix "${account}")"
  key_var="${prefix}_AWS_ACCESS_KEY_ID"
  secret_var="${prefix}_AWS_SECRET_ACCESS_KEY"
  region_var="${prefix}_AWS_REGION"

  if [[ -n "${!key_var:-}" ]]; then
    export AWS_ACCESS_KEY_ID="${!key_var}"
  else
    export AWS_ACCESS_KEY_ID="${GENERIC_AWS_ACCESS_KEY_ID}"
  fi
  if [[ -n "${!secret_var:-}" ]]; then
    export AWS_SECRET_ACCESS_KEY="${!secret_var}"
  else
    export AWS_SECRET_ACCESS_KEY="${GENERIC_AWS_SECRET_ACCESS_KEY}"
  fi

  if [[ -n "${!region_var:-}" ]]; then
    export AWS_DEFAULT_REGION="${!region_var}"
  else
    export AWS_DEFAULT_REGION="${GENERIC_AWS_REGION}"
  fi
  export AWS_REGION="${AWS_DEFAULT_REGION}"

  if [[ -z "${AWS_ACCESS_KEY_ID:-}" || -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
    echo "AWS credentials not set for account '${account}'."
    echo "Set ${key_var} and ${secret_var} (GitHub secrets) or AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY."
    return 1
  fi

  echo "Using AWS account folder '${account}' in region ${AWS_REGION}"
}

collect_locations() {
  local loc
  if [[ -n "${MANUAL_LOCATION:-}" ]]; then
    echo "${MANUAL_LOCATION%/}"
    return 0
  fi
  if [[ ! -f "${LOCATIONS_FILE}" ]]; then
    echo "No locations file at ${LOCATIONS_FILE} and MANUAL_LOCATION is unset." >&2
    return 1
  fi
  while IFS= read -r loc || [[ -n "${loc}" ]]; do
    loc="${loc%%#*}"
    loc="$(echo "${loc}" | xargs)"
    [[ -z "${loc}" ]] && continue
    echo "${loc%/}"
  done < "${LOCATIONS_FILE}"
}

run_in_directory() {
  local directory="$1"
  local abs="${REPO_ROOT}/${directory}"

  if [[ ! -d "${abs}" ]]; then
    echo "Terraform directory not found: ${directory}"
    return 1
  fi
  if ! compgen -G "${abs}/*.tf" > /dev/null; then
    echo "Skipping ${directory}: no Terraform files"
    return 0
  fi

  echo "################### Begin ${directory} (${COMMAND}) #####################"
  set_aws_credentials_for_location "${directory}"

  pushd "${abs}" >/dev/null

  terraform init -input=false -no-color

  case "${COMMAND}" in
    validate)
      terraform validate -no-color
      echo "Terraform validate complete for ${directory}."
      ;;
    plan)
      terraform plan -input=false -out=terraform.tfplan -no-color
      terraform show -json terraform.tfplan > terraform.json
      "${REPO_ROOT}/scripts/terraform_validator.sh"
      echo "Terraform plan complete for ${directory}."
      ;;
    apply)
      echo "Running terraform apply (production branch: ${BRANCH:-main})."
      terraform apply -input=false -auto-approve -no-color
      echo "Terraform apply complete for ${directory}."
      ;;
  esac

  popd >/dev/null
  echo "################### End ${directory} #####################"
}

mapfile -t LOCATIONS < <(collect_locations)
if [[ "${#LOCATIONS[@]}" -eq 0 ]]; then
  echo "No Terraform locations to process."
  exit 0
fi

for directory in "${LOCATIONS[@]}"; do
  run_in_directory "${directory}"
done

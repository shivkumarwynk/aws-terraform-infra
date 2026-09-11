#!/usr/bin/env bash
set -euo pipefail

# Detect Terraform working directories that changed under known AWS account folders.
# Prints unique paths (one per line) to stdout.
# Usage:
#   detect_changed_locations.sh [base_ref] [head_ref]
# Env:
#   MANUAL_LOCATION  - if set, only this directory is used (workflow_dispatch)

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ACCOUNTS_FILE="${REPO_ROOT}/scripts/aws-accounts.txt"
BASE_REF="${1:-}"
HEAD_REF="${2:-HEAD}"

is_account() {
  local candidate="$1"
  local line
  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line%%#*}"
    line="$(echo "${line}" | xargs)"
    [[ -z "${line}" ]] && continue
    if [[ "${line}" == "${candidate}" ]]; then
      return 0
    fi
  done < "${ACCOUNTS_FILE}"
  return 1
}

is_terraform_dir() {
  local dir="$1"
  [[ -d "${dir}" ]] || return 1
  compgen -G "${dir}/*.tf" > /dev/null
}

emit_location() {
  local rel="$1"
  rel="${rel%/}"
  [[ -n "${rel}" ]] || return 0
  if is_terraform_dir "${REPO_ROOT}/${rel}"; then
    printf '%s\n' "${rel}"
  fi
}

if [[ -n "${MANUAL_LOCATION:-}" ]]; then
  emit_location "${MANUAL_LOCATION}"
  exit 0
fi

if [[ ! -d "${REPO_ROOT}/.git" ]]; then
  echo "Not a git repository; cannot detect changed locations." >&2
  exit 1
fi

cd "${REPO_ROOT}"

changed_files=()
if [[ -n "${BASE_REF}" ]]; then
  if [[ "${BASE_REF}" =~ ^0+$ ]]; then
    mapfile -t changed_files < <(git ls-files)
  elif git rev-parse --verify "${BASE_REF}^{commit}" >/dev/null 2>&1; then
    mapfile -t changed_files < <(git diff --name-only "${BASE_REF}" "${HEAD_REF}" || true)
  else
    mapfile -t changed_files < <(git diff --name-only "${HEAD_REF}^" "${HEAD_REF}" 2>/dev/null || git ls-files)
  fi
else
  if git rev-parse --verify HEAD^ >/dev/null 2>&1; then
    mapfile -t changed_files < <(git diff --name-only HEAD^ HEAD || true)
  else
    mapfile -t changed_files < <(git ls-files)
  fi
fi

declare -A seen=()
for file in "${changed_files[@]}"; do
  [[ -z "${file}" ]] && continue
  account="${file%%/*}"
  if ! is_account "${account}"; then
    continue
  fi
  # Account folder / terraform-stack (e.g. enterprise/ec2)
  stack="$(printf '%s\n' "${file}" | cut -d/ -f1-2)"
  if [[ "${stack}" == "${account}" ]]; then
    continue
  fi
  if [[ -z "${seen[${stack}]+x}" ]]; then
    seen["${stack}"]=1
    emit_location "${stack}"
  fi
done

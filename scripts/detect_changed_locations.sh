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
DEPENDENCIES_FILE="${REPO_ROOT}/scripts/stack-dependencies.txt"
BASE_REF="${1:-}"
HEAD_REF="${2:-HEAD}"

load_accounts() {
  local line
  ACCOUNTS=()
  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line%%#*}"
    line="$(echo "${line}" | xargs)"
    [[ -z "${line}" ]] && continue
    ACCOUNTS+=("${line}")
  done < "${ACCOUNTS_FILE}"
}

is_account() {
  local candidate="$1"
  local account
  for account in "${ACCOUNTS[@]}"; do
    if [[ "${account}" == "${candidate}" ]]; then
      return 0
    fi
  done
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
    return 0
  fi
  return 1
}

list_all_account_stacks() {
  local account terraform_file stack
  local -A emitted=()
  shopt -s nullglob globstar
  for account in "${ACCOUNTS[@]}"; do
    [[ -d "${REPO_ROOT}/${account}" ]] || continue
    for terraform_file in "${REPO_ROOT}/${account}"/**/*.tf; do
      stack="$(dirname "${terraform_file}")"
      stack="${stack#"${REPO_ROOT}/"}"
      if [[ -z "${emitted[${stack}]+x}" ]]; then
        emitted["${stack}"]=1
        emit_location "${stack}" || true
      fi
    done
  done
  shopt -u nullglob globstar
}

find_stack_for_file() {
  local file="$1"
  local directory="${file%/*}"

  while [[ "${directory}" == */* ]]; do
    if is_terraform_dir "${REPO_ROOT}/${directory}"; then
      printf '%s\n' "${directory}"
      return 0
    fi
    directory="${directory%/*}"
  done

  return 1
}

load_accounts

if [[ -n "${MANUAL_LOCATION:-}" ]]; then
  if ! emit_location "${MANUAL_LOCATION}"; then
    echo "Invalid MANUAL_LOCATION '${MANUAL_LOCATION}': directory not found or has no .tf files." >&2
    exit 1
  fi
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

modules_changed=0
declare -A seen=()
declare -A changed_stacks=()
locations=()

record_location() {
  local stack="$1"
  if [[ -n "${seen[${stack}]+x}" ]]; then
    return 0
  fi
  if emit_location "${stack}"; then
    seen["${stack}"]=1
    locations+=("${stack}")
  fi
}

for file in "${changed_files[@]}"; do
  [[ -z "${file}" ]] && continue
  if [[ "${file}" == modules/* ]]; then
    modules_changed=1
    continue
  fi
  account="${file%%/*}"
  if ! is_account "${account}"; then
    continue
  fi
  # Record the environment/common directory for dependency expansion.
  changed_group="$(printf '%s\n' "${file}" | cut -d/ -f1-2)"
  changed_stacks["${changed_group}"]=1

  # Support nested roots such as enterprise/prod/vpc.
  if stack="$(find_stack_for_file "${file}")"; then
    record_location "${stack}" >/dev/null
  fi
done

# Add consumers when an upstream stack changed. Format:
#   account/upstream: account/dependent-one account/dependent-two
if [[ -f "${DEPENDENCIES_FILE}" ]]; then
  dependencies_added=1
  while [[ "${dependencies_added}" -eq 1 ]]; do
    dependencies_added=0
    while IFS= read -r line || [[ -n "${line}" ]]; do
      line="${line%%#*}"
      line="$(echo "${line}" | xargs)"
      [[ -z "${line}" ]] && continue

      upstream="${line%%:*}"
      downstream="${line#*:}"
      upstream="$(echo "${upstream}" | xargs)"
      if [[ -z "${seen[${upstream}]+x}" && -z "${changed_stacks[${upstream}]+x}" ]]; then
        continue
      fi

      for dependent in ${downstream}; do
        if [[ -z "${seen[${dependent}]+x}" ]] && is_terraform_dir "${REPO_ROOT}/${dependent}"; then
          record_location "${dependent}" >/dev/null
          dependencies_added=1
        fi
      done
    done < "${DEPENDENCIES_FILE}"
  done
fi

if [[ "${modules_changed}" -eq 1 ]]; then
  echo "Shared modules changed; including all Terraform stacks under account folders." >&2
  while IFS= read -r stack || [[ -n "${stack}" ]]; do
    [[ -z "${stack}" ]] && continue
    record_location "${stack}" >/dev/null
  done < <(list_all_account_stacks)
fi

if [[ "${#locations[@]}" -gt 0 ]]; then
  printf '%s\n' "${locations[@]}"
fi

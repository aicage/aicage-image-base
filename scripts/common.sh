#!/usr/bin/env bash
set -euo pipefail

BASE_DEFINITIONS_DIR="${ROOT_DIR}/bases"

_die() {
  if command -v die >/dev/null 2>&1; then
    die "$@"
  else
    echo "[common] $*" >&2
    exit 1
  fi
}

load_config_file() {
  local config_file="${ROOT_DIR}/config.yaml"
  [[ -f "${config_file}" ]] || _die "Config file not found: ${config_file}"

  while IFS=$'\t' read -r key value; do
    [[ -z "${key}" ]] && continue
    if [[ -z ${!key+x} ]]; then
      export "${key}=${value}"
    fi
  done < <(yq -er 'to_entries[] | [.key, (.value // "")] | @tsv' "${config_file}")
}

get_base_field() {
  local alias="$1"
  local field="$2"
  local base_dir="${BASE_DEFINITIONS_DIR}/${alias}"
  local definition_file="${base_dir}/base.yaml"

  [[ -d "${base_dir}" ]] || _die "Base alias '${alias}' not found under ${BASE_DEFINITIONS_DIR}"
  [[ -f "${definition_file}" ]] || _die "Missing base.yaml for '${alias}'"

  local value
  value="$(yq -er ".${field}" "${definition_file}")" || _die "Failed to read ${field} from ${definition_file}"
  [[ -n "${value}" && "${value}" != "null" ]] || _die "${field} missing in ${definition_file}"
  printf '%s\n' "${value}"
}

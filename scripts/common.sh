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

# add retry and other params to reduce failure in pipelines
curl_wrapper() {
  curl -fsSL \
    --retry 8 \
    --retry-all-errors \
    --retry-delay 2 \
    --max-time 600 \
    "$@"
}

load_config_file() {
  local config_file="${ROOT_DIR}/config.yml"
  [[ -f "${config_file}" ]] || _die "Config file not found: ${config_file}"

  while IFS=$'\t' read -r key value; do
    [[ -z "${key}" ]] && continue
    if [[ -z ${!key+x} ]]; then
      export "${key}=${value}"
    fi
  done < <(yq -er 'to_entries[] | [.key, (.value // "")] | @tsv' "${config_file}")
}

_get_github_repository_url() {
  local repository="$1"
  printf 'https://github.com/%s\n' "${repository}"
}

get_image_base_ref() {
  printf '%s/%s\n' "${AICAGE_IMAGE_REGISTRY}" "${AICAGE_IMAGE_BASE_REPOSITORY}"
}

get_image_base_source_url() {
  _get_github_repository_url "${AICAGE_IMAGE_BASE_SOURCE_REPOSITORY}"
}

_read_yaml_field() {
  local alias="$1"
  local field="$2"
  local definition_filename="$3"

  local base_dir="${BASE_DEFINITIONS_DIR}/${alias}"
  local definition_file="${base_dir}/${definition_filename}"
  local value

  [[ -d "${base_dir}" ]] || _die "Base alias '${alias}' not found under ${BASE_DEFINITIONS_DIR}"
  [[ -f "${definition_file}" ]] || _die "Missing ${definition_filename} for '${alias}'"

  value="$(yq -er ".${field}" "${definition_file}")" || _die "Failed to read ${field} from ${definition_file}"
  [[ -n "${value}" && "${value}" != "null" ]] || _die "${field} missing in ${definition_file}"
  printf '%s\n' "${value}"
}

get_base_field() {
  local alias="$1"
  local field="$2"
  _read_yaml_field "${alias}" "${field}" base.yml
}

get_base_build_field() {
  local alias="$1"
  local field="$2"
  _read_yaml_field "${alias}" "${field}" base-build.yml
}

get_base_list_field() {
  local alias="$1"
  local field="$2"
  local definition_file="${BASE_DEFINITIONS_DIR}/${alias}/base.yml"

  [[ -f "${definition_file}" ]] || _die "Missing base.yml for '${alias}'"

  yq -r ".${field} // [] | .[]" "${definition_file}" \
    || _die "Failed to read ${field} from ${definition_file}"
}

get_base_architectures() {
  local alias="$1"
  get_base_list_field "${alias}" architectures
}

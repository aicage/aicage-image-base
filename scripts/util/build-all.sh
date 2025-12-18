#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

die() {
  echo "[build-base-all] $*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Usage: scripts/build-all.sh [build-options]

Builds all base-image variants. Options after the script name are forwarded to
scripts/build.sh for each build (e.g., --platform). Platforms must come from --platform
or environment (config.yaml).

Options:
  --platform <value>  Build only a single platform (e.g., linux/amd64)
  --version <value>   Override AICAGE_VERSION
  -h, --help          Show this help and exit
USAGE
  exit 1
}

# shellcheck source=../scripts/common.sh
source "${ROOT_DIR}/scripts/common.sh"

if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
  usage
fi

load_config_file

while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform)
      [[ $# -ge 2 ]] || { echo "[build-base-all] --platform requires a value" >&2; exit 1; }
      AICAGE_PLATFORMS="$2"
      shift 2
      ;;
    --version)
      [[ $# -ge 2 ]] || { echo "[build-base-all] --version requires a value" >&2; exit 1; }
      AICAGE_VERSION="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      die "Unexpected argument '$1'"
      ;;
  esac
done

for base_dir in "${ROOT_DIR}/bases"/*; do
  BASE_ALIAS="$(basename "${base_dir}")"
  BASE_IMAGE="$(get_base_field "${BASE_ALIAS}" base_image)"
  INSTALLER="$(get_base_field "${BASE_ALIAS}" os_installer)"
  echo "[build-base-all] Building ${BASE_ALIAS} (upstream: ${BASE_IMAGE}; platforms: ${AICAGE_PLATFORMS})" >&2
  "${ROOT_DIR}/scripts/build.sh" --base "${BASE_ALIAS}" --platform "${AICAGE_PLATFORMS}" --version "${AICAGE_VERSION}"
done

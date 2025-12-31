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
scripts/build.sh for each build.

Options:
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
  ROOT_IMAGE="$(get_base_field "${BASE_ALIAS}" root_image)"
  echo "[build-base-all] Building ${BASE_ALIAS} (upstream: ${ROOT_IMAGE}" >&2
  "${ROOT_DIR}/scripts/util/build.sh" --base "${BASE_ALIAS}" --version "${AICAGE_VERSION}"
done

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

die() {
  echo "[build-base] $*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Usage: scripts/build.sh [--base <alias>] [options]

Options:
  --base <value>       Base alias (required; must match a bases/<name> folder)
  --version <value>    Override AICAGE_VERSION for this build
  -h, --help           Show this help and exit

Examples:
  scripts/build.sh --base ubuntu
USAGE
  exit 1
}

# shellcheck source=../../scripts/common.sh
source "${ROOT_DIR}/scripts/common.sh"

BASE_ALIAS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)
      [[ $# -ge 2 ]] || die "--base requires a value"
      BASE_ALIAS="$2"
      shift 2
      ;;
    --version)
      [[ $# -ge 2 ]] || die "--version requires a value"
      AICAGE_VERSION="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    --)
      shift
      break
      ;;
    *)
      die "Unknown option '$1'"
      ;;
  esac
done

[[ -n "${BASE_ALIAS}" ]] || die "--base is required"

load_config_file

ROOT_IMAGE="$(get_base_field "${BASE_ALIAS}" root_image)"
BASE_IMAGE_DISTRO="$(get_base_field "${BASE_ALIAS}" base_image_distro)"
BASE_IMAGE_DESCRIPTION="$(get_base_field "${BASE_ALIAS}" base_image_description)"
OS_INSTALLER="$(get_base_field "${BASE_ALIAS}" os_installer)"
OS_INSTALLER_PATH="${ROOT_DIR}/scripts/os-installers/${OS_INSTALLER}"
[[ -f "${OS_INSTALLER_PATH}" ]] || die "OS installer not found for '${BASE_ALIAS}': ${OS_INSTALLER}"

VERSION_TAG="${AICAGE_IMAGE_REGISTRY}/${AICAGE_IMAGE_BASE_REPOSITORY}:${BASE_ALIAS}-${AICAGE_VERSION}"
LATEST_TAG="${AICAGE_IMAGE_REGISTRY}/${AICAGE_IMAGE_BASE_REPOSITORY}:${BASE_ALIAS}"

(
echo "UpstreamBase=${ROOT_IMAGE}"
 echo "Installer=${OS_INSTALLER}"
 echo "Tags=${VERSION_TAG},${LATEST_TAG}"
) >&2

docker build \
  --build-arg "ROOT_IMAGE=${ROOT_IMAGE}" \
  --build-arg "OS_INSTALLER=${OS_INSTALLER}" \
  --tag "${VERSION_TAG}" \
  --tag "${LATEST_TAG}" \
  --label "org.opencontainers.image.description=Base image for aicage (${BASE_ALIAS})" \
  --label "org.aicage.base=${BASE_ALIAS}" \
  --label "org.aicage.base.distro=${BASE_IMAGE_DISTRO}" \
  --label "org.aicage.base.description=${BASE_IMAGE_DESCRIPTION}" \
  .

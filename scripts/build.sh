#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

die() {
  echo "[build-base] $*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Usage: scripts/build.sh [--base <alias>] [options]

Options:
  --base <value>       Base alias (required; must match a bases/<name> folder)
  --platform <value>   Override platform list (default: linux/amd64,linux/arm64)
  --push               Push the image instead of loading it locally
  --version <value>    Override AICAGE_VERSION for this build
  -h, --help           Show this help and exit

Examples:
  scripts/build.sh --base ubuntu:24.04
  scripts/build.sh --base ghcr.io/catthehacker/ubuntu:act-latest --platform linux/amd64
USAGE
  exit 1
}

# shellcheck source=../scripts/common.sh
source "${ROOT_DIR}/scripts/common.sh"

PUSH_MODE="--load"
BASE_ALIAS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)
      [[ $# -ge 2 ]] || die "--base requires a value"
      BASE_ALIAS="$2"
      shift 2
      ;;
    --platform)
      [[ $# -ge 2 ]] || die "--platform requires a value"
      AICAGE_PLATFORMS="$2"
      shift 2
      ;;
    --push)
      PUSH_MODE="--push"
      shift
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

BASE_IMAGE="$(get_base_field "${BASE_ALIAS}" base_image)"
OS_INSTALLER="$(get_base_field "${BASE_ALIAS}" os_installer)"
OS_INSTALLER_PATH="${ROOT_DIR}/scripts/os-installers/${OS_INSTALLER}"
[[ -f "${OS_INSTALLER_PATH}" ]] || die "OS installer not found for '${BASE_ALIAS}': ${OS_INSTALLER}"

TARGET="base-${BASE_ALIAS}"
VERSION_TAG="${AICAGE_IMAGE_BASE_REPOSITORY}:${BASE_ALIAS}-${AICAGE_VERSION}"
LATEST_TAG="${AICAGE_IMAGE_BASE_REPOSITORY}:${BASE_ALIAS}-latest"
DESCRIPTION="Base image for aicage (${BASE_ALIAS})"

echo "[build-base] Target=${TARGET} Platforms=${AICAGE_PLATFORMS} Repo=${AICAGE_IMAGE_BASE_REPOSITORY} Version=${AICAGE_VERSION} UpstreamBase=${BASE_IMAGE} Installer=${OS_INSTALLER} Tags=${VERSION_TAG},${LATEST_TAG} Mode=${PUSH_MODE}" >&2
env \
  "AICAGE_IMAGE_BASE_REPOSITORY=${AICAGE_IMAGE_BASE_REPOSITORY}" \
  "AICAGE_VERSION=${AICAGE_VERSION}" \
  "AICAGE_PLATFORMS=${AICAGE_PLATFORMS}" \
  docker buildx bake \
    -f "${ROOT_DIR}/docker-bake.hcl" \
    base \
    --set "base.args.BASE_IMAGE=${BASE_IMAGE}" \
    --set "base.args.OS_INSTALLER=${OS_INSTALLER}" \
    --set "base.tags=${VERSION_TAG}" \
    --set "base.tags+=${LATEST_TAG}" \
    --set "base.labels.org.opencontainers.image.description=${DESCRIPTION}" \
    "${PUSH_MODE}"

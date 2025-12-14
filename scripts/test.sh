#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SMOKE_DIR="${ROOT_DIR}/tests/smoke"
IMAGE_REF=""

usage() {
  cat <<'USAGE'
Usage: scripts/test.sh --image <image-ref> [-- <bats-args>]

Options:
  -h, --help      Show this help and exit

Examples:
  scripts/test.sh --image wuodan/aicage-image-base:ubuntu-latest
USAGE
  exit 1
}

# shellcheck source=../scripts/common.sh
source "${ROOT_DIR}/scripts/common.sh"

log() {
  printf '[base-test] %s\n' "$*" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image)
      [[ $# -ge 2 ]] || usage
      IMAGE_REF="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      usage
      ;;
  esac
done

[[ -n "${IMAGE_REF}" ]] || { log "--image is required"; usage; }

log "Running base smoke tests via bats"
AICAGE_IMAGE_BASE_IMAGE="${IMAGE_REF}" bats "${SMOKE_DIR}" "$@"

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SMOKE_DIR="${ROOT_DIR}/tests/smoke"
IMAGE_REF=""
BASE_ALIAS=""

usage() {
  cat <<'USAGE'
Usage: scripts/test.sh --image <image-ref> [-- <bats-args>]

Options:
  -h, --help      Show this help and exit

Examples:
  scripts/test.sh --image ghcr.io/aicage/aicage-image-base:ubuntu
USAGE
  exit 1
}

# shellcheck source=../scripts/common.sh
source "${ROOT_DIR}/scripts/common.sh"

log() {
  printf '[base-test] %s\n' "$*" >&2
}

die() {
  log "$*"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image)
      [[ $# -ge 2 ]] || usage
      IMAGE_REF="$2"
      shift 2
      ;;
    --base)
      [[ $# -ge 2 ]] || die "--base requires a value"
      BASE_ALIAS="$2"
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
[[ -n "${BASE_ALIAS}" ]] || { log "--base is required"; usage; }

if ! TEST_SUITE="$(get_base_build_field "${BASE_ALIAS}" test_suite)"; then
  TEST_SUITE="default"
fi
[[ -n "${TEST_SUITE}" ]] || die "Test suite not defined"
[[ -d "${SMOKE_DIR}/${TEST_SUITE}" ]] || die "Test suite folder not found"

log "Running base smoke test suite '${TEST_SUITE}' via bats"
AICAGE_IMAGE_BASE_IMAGE="${IMAGE_REF}" \
  BASE_ALIAS="${BASE_ALIAS}" \
  bats "${SMOKE_DIR}/${TEST_SUITE}" "$@"

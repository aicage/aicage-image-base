#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

die() {
  echo "[base-test-all] $*" >&2
  exit 1
}

# shellcheck source=../scripts/common.sh
source "${ROOT_DIR}/scripts/common.sh"

load_config_file

for base_dir in "${ROOT_DIR}/bases"/*; do
  BASE_ALIAS="$(basename "${base_dir}")"
  IMAGE="${AICAGE_IMAGE_REGISTRY}/${AICAGE_IMAGE_BASE_REPOSITORY}:${BASE_ALIAS}-${AICAGE_VERSION}"
  echo "[base-test-all] Testing ${IMAGE}" >&2
  "${ROOT_DIR}/scripts/test.sh" --image "${IMAGE}" --base "${BASE_ALIAS}" -- "$@"
done

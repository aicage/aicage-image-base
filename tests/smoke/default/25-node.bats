#!/usr/bin/env bats

@test "node toolchain present" {
  run docker run --rm \
    --env AICAGE_WORKSPACE=/workspace \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -c '
      set -euo pipefail
      command -v node
      command -v npm
      command -v corepack
      command -v xdg-open
    '
  [ "$status" -eq 0 ]
}

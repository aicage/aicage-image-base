#!/usr/bin/env bats

@test "python toolchain present" {
  run docker run --rm \
    --env AICAGE_WORKSPACE=/workspace \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -c '
      set -euo pipefail
      command -v python3
      command -v pipx
      command -v python3-config
    '
  [ "$status" -eq 0 ]
}

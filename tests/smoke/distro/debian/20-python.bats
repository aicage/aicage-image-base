#!/usr/bin/env bats

@test "python toolchain present" {
  run docker run --rm \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    /bin/bash -lc "set -euo pipefail
      command -v python3
      command -v pipx
      command -v python3-config"
  [ "$status" -eq 0 ]
}

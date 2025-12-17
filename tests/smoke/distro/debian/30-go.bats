#!/usr/bin/env bats

@test "go toolchain present" {
  run docker run --rm \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    /bin/bash -lc "set -euo pipefail
      command -v go"
  [ "$status" -eq 0 ]
}

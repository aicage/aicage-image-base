#!/usr/bin/env bats

@test "gradle present" {
  run docker run --rm \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    /bin/bash -lc "set -euo pipefail
      command -v gradle"
  [ "$status" -eq 0 ]
}

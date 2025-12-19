#!/usr/bin/env bats

@test "core utilities present" {
  run docker run --rm \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    /bin/bash -c '
      set -euo pipefail
      command -v tini
    '
  [ "$status" -eq 0 ]
}

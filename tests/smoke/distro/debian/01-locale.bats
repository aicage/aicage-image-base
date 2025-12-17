#!/usr/bin/env bats

@test "locale available" {
  run docker run --rm \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    /bin/bash -lc "set -euo pipefail
      locale -a | grep -q '^en_US\\.utf8$'"
  [ "$status" -eq 0 ]
}

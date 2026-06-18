#!/usr/bin/env bats

@test "perl present" {
  run docker run --rm \
    --env AICAGE_WORKSPACE=/workspace \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -c '
      set -euo pipefail
      command -v perl
      perl -e '\''print "ok\n"'\'' | grep -qx ok
    '
  [ "$status" -eq 0 ]
}

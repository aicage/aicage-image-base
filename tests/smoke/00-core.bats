#!/usr/bin/env bats

@test "core utilities present" {
  run docker run --rm \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    /bin/bash -c '
      set -euo pipefail
      command -v dig
      command -v ip
      command -v rsync
      command -v tree
      command -v patch
      command -v file
      command -v less
      command -v 7z >/dev/null || command -v 7za >/dev/null
      command -v tini
    '
  [ "$status" -eq 0 ]
}

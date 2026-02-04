#!/usr/bin/env bats

@test "core utilities present" {
  run docker run --rm \
    --env AICAGE_WORKSPACE=/workspace \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -c '
      set -euo pipefail
      command -v dig
      command -v ip
      command -v curl
      command -v rsync
      command -v tree
      command -v patch
      command -v file
      command -v less
      command -v 7z >/dev/null || command -v 7za >/dev/null
      command -v git
      command -v tini
    '
  [ "$status" -eq 0 ]
}

#!/usr/bin/env bats

@test "imagemagick present" {
  run docker run --rm \
    --env AICAGE_WORKSPACE=/workspace \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -c '
      set -euo pipefail
      command -v magick >/dev/null || command -v convert >/dev/null
    '
  [ "$status" -eq 0 ]
}

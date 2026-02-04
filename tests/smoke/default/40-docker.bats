#!/usr/bin/env bats

@test "docker cli present" {
  run docker run --rm \
    --env AICAGE_WORKSPACE=/workspace \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -c '
      set -euo pipefail
      docker --version
      docker buildx version
    '
  [ "$status" -eq 0 ]
}

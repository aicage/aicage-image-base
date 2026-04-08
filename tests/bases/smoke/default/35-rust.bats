#!/usr/bin/env bats

@test "rust toolchain present" {
  run docker run --rm \
    --env AICAGE_WORKSPACE=/workspace \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -c '
      set -euo pipefail
      command -v rustc
      command -v cargo
      command -v rustfmt
      command -v clippy-driver >/dev/null || command -v cargo-clippy >/dev/null
    '
  [ "$status" -eq 0 ]
}

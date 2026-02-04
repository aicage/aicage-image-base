#!/usr/bin/env bats

@test "java toolchain present" {
  run docker run --rm \
    --env AICAGE_WORKSPACE=/workspace \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -c '
      set -euo pipefail
      command -v java
      command -v javac
      command -v mvn
      command -v ant
      command -v protoc
    '
  [ "$status" -eq 0 ]
}

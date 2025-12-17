#!/usr/bin/env bats

@test "java toolchain present" {
  run docker run --rm \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    /bin/bash -lc "set -euo pipefail
      command -v java
      command -v javac
      command -v mvn
      command -v ant
      command -v protoc"
  [ "$status" -eq 0 ]
}

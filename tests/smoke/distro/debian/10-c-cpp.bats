#!/usr/bin/env bats

@test "c/c++ toolchain present" {
  run docker run --rm \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    /bin/bash -lc "set -euo pipefail
      command -v gcc
      command -v g++
      command -v cmake
      command -v ninja
      command -v clang
      command -v lldb
      command -v gdb
      command -v pkg-config
      command -v valgrind
      command -v strace
      command -v ltrace
      command -v ld.lld >/dev/null || command -v lld >/dev/null"
  [ "$status" -eq 0 ]
}

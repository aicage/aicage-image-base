#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../../helpers/os.bash"

setup_file() {
  require_fedora
}

@test "gradle present" {
  run docker run --rm \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    /bin/bash -lc "set -euo pipefail
      command -v gradle"
  [ "$status" -eq 0 ]
}

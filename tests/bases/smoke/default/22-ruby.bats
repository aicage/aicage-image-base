#!/usr/bin/env bats

@test "ruby toolchain present" {
  run docker run --rm \
    --env AICAGE_WORKSPACE=/workspace \
    --env AICAGE_HOST_IS_LINUX=true \
    --env AICAGE_UID=1234 \
    --env AICAGE_GID=2345 \
    --env AICAGE_HOST_USER=demo \
    --env AICAGE_HOME=/home/demo \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -c '
      set -euo pipefail
      command -v ruby
      command -v gem
      command -v bundle
      ruby -e '\''puts "ok"'\'' | grep -qx ok
    '
  [ "$status" -eq 0 ]
}

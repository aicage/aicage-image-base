#!/usr/bin/env bats

@test "node toolchain present" {
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
      command -v node
      command -v npm
      command -v corepack
      command -v xdg-open
      node -e '\''console.log("ok-node")'\'' | grep -qx ok-node
      npm --version >/dev/null
      corepack --version >/dev/null
    '
  [ "$status" -eq 0 ]
}

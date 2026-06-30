#!/usr/bin/env bats

@test "database clients present" {
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
      command -v sqlite3
      sqlite3 :memory: "select '\''ok-sqlite'\'';" | grep -qx ok-sqlite
      psql --version >/dev/null
      mysql --version >/dev/null || mariadb --version >/dev/null
    '
  [ "$status" -eq 0 ]
}

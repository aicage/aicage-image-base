#!/usr/bin/env bats

@test "database clients present" {
  run docker run --rm \
    --env AICAGE_WORKSPACE=/workspace \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -c '
      set -euo pipefail
      command -v sqlite3
      command -v psql
      command -v mysql >/dev/null || command -v mariadb >/dev/null
    '
  [ "$status" -eq 0 ]
}

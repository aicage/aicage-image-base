#!/usr/bin/env bats

@test "locale available" {
  run docker run --rm \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    /bin/bash -c '
      set -euo pipefail
      . /etc/os-release

      if [[ "${ID:-}" == "alpine" ]]; then
        locale -a | grep -q "^C\.UTF-8$"
        locale | grep -q "^LANG=C\.UTF-8$"
        locale | grep -q "^LC_ALL=C\.UTF-8$"
      else
        locale -a | grep -q "^en_US\.utf8$"
        locale -a | grep -q "^de_CH\.utf8$"
      fi
    '
  [ "$status" -eq 0 ]
}

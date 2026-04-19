#!/usr/bin/env bats

@test "tzdata present" {
  run docker run --rm \
    --env AICAGE_WORKSPACE=/workspace \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -c '
      set -euo pipefail
      test -d /usr/share/zoneinfo
      test -e /usr/share/zoneinfo/UTC
      test -e /usr/share/zoneinfo/Europe/Zurich
      test -e /usr/share/zoneinfo/America/New_York
    '
  [ "$status" -eq 0 ]
}

@test "entrypoint applies timezone from TZ" {
  run docker run --rm \
    --env AICAGE_WORKSPACE=/workspace \
    --env TZ=Europe/Zurich \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -c '
      set -euo pipefail
      [[ "$(cat /etc/timezone)" == "Europe/Zurich" ]]
      [[ "$(readlink -f /etc/localtime)" == "/usr/share/zoneinfo/Europe/Zurich" ]]
      python3 - <<'"'"'PY'"'"'
from datetime import datetime
import time

offset = datetime.now().astimezone().strftime("%z")
tzname = time.tzname[0]
assert offset in {"+0100", "+0200"}, offset
assert tzname in {"CET", "CEST"}, tzname
PY
    '
  [ "$status" -eq 0 ]
}

@test "entrypoint applies alternate timezone from TZ" {
  run docker run --rm \
    --env AICAGE_WORKSPACE=/workspace \
    --env TZ=America/New_York \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -c '
      set -euo pipefail
      [[ "$(cat /etc/timezone)" == "America/New_York" ]]
      [[ "$(readlink -f /etc/localtime)" == "/usr/share/zoneinfo/America/New_York" ]]
      python3 - <<'"'"'PY'"'"'
from datetime import datetime
import time

offset = datetime.now().astimezone().strftime("%z")
tzname = time.tzname[0]
assert offset in {"-0500", "-0400"}, offset
assert tzname in {"EST", "EDT"}, tzname
PY
    '
  [ "$status" -eq 0 ]
}

@test "entrypoint rejects unknown timezone" {
  run docker run --rm \
    --env AICAGE_WORKSPACE=/workspace \
    --env TZ=Not/A_Zone \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -c 'set -euo pipefail'
  [ "$status" -ne 0 ]
  [[ "${output}" == *"Requested timezone not found: Not/A_Zone"* ]]
}

#!/usr/bin/env bats

@test "workspace must be set" {
  run docker run --rm \
    --env AICAGE_HOST_IS_LINUX=true \
    --env AICAGE_UID=1234 \
    --env AICAGE_GID=2345 \
    --env AICAGE_HOST_USER=demo \
    --env AICAGE_HOME=/home/demo \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -c '
      set -euo pipefail
      printf "%s\n%s\n" "${AICAGE_WORKSPACE}" "${PWD}"
    '
  [ "$status" -ne 0 ]
}

@test "workspace respects AICAGE_WORKSPACE override" {
  run docker run --rm \
    --env AICAGE_HOST_IS_LINUX=true \
    --env AICAGE_UID=1234 \
    --env AICAGE_GID=2345 \
    --env AICAGE_HOST_USER=demo \
    --env AICAGE_HOME=/home/demo \
    --env AICAGE_WORKSPACE=/custom/workspace \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -c '
      set -euo pipefail
      printf "%s\n%s\n" "${AICAGE_WORKSPACE}" "${PWD}"
    '
  [ "$status" -eq 0 ]
  mapfile -t lines <<<"${output}"
  workspace="${lines[0]}"
  pwd="${lines[1]}"
  [[ "${workspace}" == "/custom/workspace" ]]
  [[ "${pwd}" == "/custom/workspace" ]]
}

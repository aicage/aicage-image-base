#!/usr/bin/env bats

@test "workspace defaults to /workspace" {
  run docker run --rm \
    --env AICAGE_UID=1234 \
    --env AICAGE_GID=2345 \
    --env AICAGE_USER=demo \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -c '
      set -euo pipefail
      printf "%s\n%s\n" "${AICAGE_WORKSPACE}" "${PWD}"
    '
  [ "$status" -eq 0 ]
  mapfile -t lines <<<"${output}"
  workspace="${lines[0]}"
  pwd="${lines[1]}"
  [[ "${workspace}" == "/workspace" ]]
  [[ "${pwd}" == "/workspace" ]]
}

@test "workspace respects AICAGE_WORKSPACE override" {
  run docker run --rm \
    --env AICAGE_UID=1234 \
    --env AICAGE_GID=2345 \
    --env AICAGE_USER=demo \
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

@test "workspace ownership is set for non-root and /workspace fallback" {
  run docker run --rm \
    --env AICAGE_UID=1234 \
    --env AICAGE_GID=2345 \
    --env AICAGE_USER=demo \
    --env AICAGE_WORKSPACE=/custom/workspace \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -c '
      set -euo pipefail
      printf "%s\n%s\n" "$(stat -c "%u:%g" /custom/workspace)" "$(stat -c "%u:%g" /workspace)"
    '
  [ "$status" -eq 0 ]
  mapfile -t lines <<<"${output}"
  workspace_owner="${lines[0]}"
  fallback_owner="${lines[1]}"
  [[ "${workspace_owner}" == "1234:2345" ]]
  [[ "${fallback_owner}" == "1234:2345" ]]
}

@test "workspace ownership is set for root and /workspace fallback" {
  run docker run --rm \
    --env AICAGE_UID=0 \
    --env AICAGE_GID=0 \
    --env AICAGE_USER=demo \
    --env AICAGE_WORKSPACE=/custom/workspace \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -c '
      set -euo pipefail
      printf "%s\n%s\n" "$(stat -c "%u:%g" /custom/workspace)" "$(stat -c "%u:%g" /workspace)"
    '
  [ "$status" -eq 0 ]
  mapfile -t lines <<<"${output}"
  workspace_owner="${lines[0]}"
  fallback_owner="${lines[1]}"
  [[ "${workspace_owner}" == "0:0" ]]
  [[ "${fallback_owner}" == "0:0" ]]
}

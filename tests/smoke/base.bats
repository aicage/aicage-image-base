#!/usr/bin/env bats

@test "base image has core runtimes" {
  run docker run --rm "${AICAGE_IMAGE_BASE_IMAGE}" /bin/bash -lc "echo base-smoke"
  [ "$status" -eq 0 ]
  [[ "$output" == *"base-smoke"* ]]
}

@test "test_runtime_user_creation" {
  run docker run --rm \
    --env AICAGE_UID=1234 \
    --env AICAGE_GID=2345 \
    --env AICAGE_USER=demo \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    /bin/bash -lc "printf '%s\n%s\n%s\n' \"\$(id -u)\" \"\$(id -g)\" \"\${HOME}\""
  [ "$status" -eq 0 ]
  mapfile -t lines <<<"${output}"
  uid="${lines[0]}"
  gid="${lines[1]}"
  home="${lines[2]}"
  [ "${uid}" -eq 1234 ]
  [ "${gid}" -eq 2345 ]
  [[ "${home}" == "/home/demo" ]]
}

@test "docker CLI present" {
  run docker run --rm \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    /bin/bash -lc "docker --version"
  [ "$status" -eq 0 ]
  [[ "$output" == Docker\ version* ]]
}

@test "docker group exists and user is a member" {
  run docker run --rm \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    /bin/bash -lc "getent group docker | cut -d: -f3; id -nG"
  [ "$status" -eq 0 ]
  mapfile -t lines <<<"${output}"
  gid="${lines[0]}"
  groups="${lines[1]}"
  [[ -n "${gid}" ]]
  [[ " ${groups} " == *" docker "* ]]
}

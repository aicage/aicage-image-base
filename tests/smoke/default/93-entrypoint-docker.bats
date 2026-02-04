#!/usr/bin/env bats

@test "docker socket gid group is created and user can run docker" {
  docker_sock_gid="$(stat -c '%g' /var/run/docker.sock)"
  run docker run --rm \
    --env AICAGE_WORKSPACE=/workspace \
    -v /var/run/docker.sock:/var/run/docker.sock \
    --env AICAGE_UID=1234 \
    --env AICAGE_GID="${docker_sock_gid}" \
    --env AICAGE_USER=demo \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -c '
      set -euo pipefail
      sock_gid="$(stat -c "%g" /var/run/docker.sock)"
      group_name="$(getent group "${sock_gid}" | cut -d: -f1)"
      echo "${sock_gid}"
      echo "${group_name}"
      id -nG
      docker run --rm hello-world
    '
  [ "$status" -eq 0 ]
  mapfile -t lines <<<"${output}"
  gid="${lines[0]}"
  group_name="${lines[1]}"
  groups="${lines[2]}"
  [ "${gid}" -eq "${docker_sock_gid}" ]
  [[ -n "${group_name}" ]]
  [[ " ${groups} " == *" ${group_name} "* ]]
  [[ "${output}" == *"Hello from Docker!"* ]]
}

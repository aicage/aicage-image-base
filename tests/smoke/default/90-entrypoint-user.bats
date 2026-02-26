#!/usr/bin/env bats

@test "test_runtime_user_creation" {
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
      printf "%s\n%s\n%s\n" "$(id -u)" "$(id -g)" "${HOME}"
    '
  [ "$status" -eq 0 ]
  mapfile -t lines <<<"${output}"
  uid="${lines[0]}"
  gid="${lines[1]}"
  home="${lines[2]}"
  [ "${uid}" -eq 1234 ]
  [ "${gid}" -eq 2345 ]
  [[ "${home}" == "/home/demo" ]]
}

@test "existing uid/gid are replaced by target user/group" {
  run docker run --rm \
    --env AICAGE_WORKSPACE=/workspace \
    --entrypoint /bin/bash \
    --env AICAGE_HOST_IS_LINUX=true \
    --env AICAGE_UID=1000 \
    --env AICAGE_GID=1000 \
    --env AICAGE_HOST_USER=hostuser \
    --env AICAGE_HOME=/home/hostuser \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -c '
      set -euo pipefail
      if getent passwd hostuser >/dev/null; then
        echo "target user already exists"
        exit 2
      fi
      if getent group hostuser >/dev/null; then
        echo "target group already exists"
        exit 2
      fi
      existing_group="$(getent group 1000 | cut -d: -f1 || true)"
      if [[ -z "${existing_group}" ]]; then
        groupadd -g 1000 ubuntu
      fi
      existing_user="$(getent passwd 1000 | cut -d: -f1 || true)"
      if [[ -z "${existing_user}" ]]; then
        useradd -m -u 1000 -g 1000 -s /bin/bash ubuntu
      fi
      /usr/local/bin/entrypoint.sh -c "set -euo pipefail; echo \"\$(id -un):\$(id -gn):\$(id -u):\$(id -g):\${HOME}\"; test ! -d /home/ubuntu"
    '
  [ "$status" -eq 0 ]
  result="$(printf '%s\n' "${output}" | tail -n 1)"
  IFS=':' read -r user group uid gid home <<<"${result}"
  [ "${user}" = "hostuser" ]
  [ "${group}" = "hostuser" ]
  [ "${uid}" -eq 1000 ]
  [ "${gid}" -eq 1000 ]
  [ "${home}" = "/home/hostuser" ]
}

@test "uid 0 forces root user and home" {
  run docker run --rm \
    --env AICAGE_WORKSPACE=/workspace \
    --env AICAGE_HOST_USER=demo \
    --env AICAGE_HOME=/mnt/d/Users/demo \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -c '
      set -euo pipefail
      printf "%s\n%s\n%s\n%s\n" "$(id -u)" "$(id -g)" "$(id -un)" "${HOME}"
    '
  [ "$status" -eq 0 ]
  mapfile -t lines <<<"${output}"
  uid="${lines[0]}"
  gid="${lines[1]}"
  user="${lines[2]}"
  home="${lines[3]}"
  [ "${uid}" -eq 0 ]
  [ "${gid}" -eq 0 ]
  [ "${user}" = "root" ]
  [ "${home}" = "/root" ]
}

@test "existing home directory is reused for target user" {
  run docker run --rm \
    --env AICAGE_WORKSPACE=/workspace \
    --entrypoint /bin/bash \
    --env AICAGE_HOST_IS_LINUX=true \
    --env AICAGE_UID=2234 \
    --env AICAGE_GID=3234 \
    --env AICAGE_HOST_USER=demo \
    --env AICAGE_HOME=/home/demo \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -c '
      set -euo pipefail
      mkdir -p /home/demo
      chown 0:0 /home/demo
      /usr/local/bin/entrypoint.sh -c "set -euo pipefail; echo \"\$(id -u):\$(id -g):\${HOME}:\$(stat -c %u:%g /home/demo)\""
    '
  [ "$status" -eq 0 ]
  result="$(printf '%s\n' "${output}" | tail -n 1)"
  IFS=':' read -r uid gid home home_uid home_gid <<<"${result}"
  [ "${uid}" -eq 2234 ]
  [ "${gid}" -eq 3234 ]
  [ "${home}" = "/home/demo" ]
  [ "${home_uid}" -eq 2234 ]
  [ "${home_gid}" -eq 3234 ]
}

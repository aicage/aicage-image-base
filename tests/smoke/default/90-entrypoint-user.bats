#!/usr/bin/env bats

@test "test_runtime_user_creation" {
  run docker run --rm \
    --env AICAGE_WORKSPACE=/workspace \
    --env AICAGE_UID=1234 \
    --env AICAGE_GID=2345 \
    --env AICAGE_USER=demo \
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

@test "existing uid/gid are renamed to target user/group" {
  run docker run --rm \
    --env AICAGE_WORKSPACE=/workspace \
    --entrypoint /bin/bash \
    --env AICAGE_UID=1000 \
    --env AICAGE_GID=1000 \
    --env AICAGE_USER=hostuser \
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
      /usr/local/bin/entrypoint.sh -c "set -euo pipefail; echo \"\$(id -un):\$(id -gn):\$(id -u):\$(id -g)\""
    '
  [ "$status" -eq 0 ]
  result="$(printf '%s\n' "${output}" | tail -n 1)"
  IFS=':' read -r user group uid gid <<<"${result}"
  [ "${user}" = "hostuser" ]
  [ "${group}" = "hostuser" ]
  [ "${uid}" -eq 1000 ]
  [ "${gid}" -eq 1000 ]
}

@test "uid 0 forces root user and home" {
  run docker run --rm \
    --env AICAGE_WORKSPACE=/workspace \
    --env AICAGE_UID=0 \
    --env AICAGE_GID=0 \
    --env AICAGE_USER=demo \
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

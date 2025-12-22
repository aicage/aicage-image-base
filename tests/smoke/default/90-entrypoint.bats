#!/usr/bin/env bats

@test "test_runtime_user_creation" {
  run docker run --rm \
    --env AICAGE_UID=1234 \
    --env AICAGE_GID=2345 \
    --env AICAGE_USER=demo \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    /bin/bash -c '
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

@test "docker socket gid group is created and user can run docker" {
  docker_sock_gid="$(stat -c '%g' /var/run/docker.sock)"
  run docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    --env AICAGE_UID=1234 \
    --env AICAGE_GID="${docker_sock_gid}" \
    --env AICAGE_USER=demo \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    /bin/bash -c '
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

@test "gitconfig mount is symlinked into home and git config" {
  host_dir="$(mktemp -d)"
  trap 'rm -rf "${host_dir}"' RETURN
  chmod 755 "${host_dir}"
  printf '[user]\n  name = example\n' >"${host_dir}/gitconfig"
  chmod 644 "${host_dir}/gitconfig"

  run docker run --rm \
    -v "${host_dir}:/aicage/host:ro" \
    --env AICAGE_UID=1234 \
    --env AICAGE_GID=2345 \
    --env AICAGE_USER=demo \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    /bin/bash -c '
      set -euo pipefail
      [[ -L ${HOME}/.gitconfig ]]
      [[ -L ${HOME}/.config/git/config ]]
      [[ $(readlink -f ${HOME}/.gitconfig) == "/aicage/host/gitconfig" ]]
      [[ $(readlink -f ${HOME}/.config/git/config) == "/aicage/host/gitconfig" ]]
      cat ${HOME}/.gitconfig
    '
  [ "$status" -eq 0 ]
  [[ "$output" == *"name = example"* ]]
}

@test "gnupg and ssh mounts are symlinked into home" {
  host_dir="$(mktemp -d)"
  trap 'rm -rf "${host_dir}"' RETURN
  chmod 755 "${host_dir}"
  mkdir -p "${host_dir}/gnupg" "${host_dir}/ssh"
  chmod 755 "${host_dir}/gnupg" "${host_dir}/ssh"
  printf 'gnupg-data\n' >"${host_dir}/gnupg/config"
  printf 'ssh-data\n' >"${host_dir}/ssh/known_hosts"
  chmod 644 "${host_dir}/gnupg/config" "${host_dir}/ssh/known_hosts"

  run docker run --rm \
    -v "${host_dir}:/aicage/host:ro" \
    --env AICAGE_UID=5678 \
    --env AICAGE_GID=6789 \
    --env AICAGE_USER=agent \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    /bin/bash -c '
      set -euo pipefail
      [[ -L ${HOME}/.gnupg ]]
      [[ -L ${HOME}/.ssh ]]
      [[ $(readlink -f ${HOME}/.gnupg) == '/aicage/host/gnupg' ]]
      [[ $(readlink -f ${HOME}/.ssh) == '/aicage/host/ssh' ]]
      cat ${HOME}/.gnupg/config
      cat ${HOME}/.ssh/known_hosts
    '
  [ "$status" -eq 0 ]
  [[ "$output" == *"gnupg-data"* ]]
  [[ "$output" == *"ssh-data"* ]]
}

@test "existing uid/gid are renamed to target user/group" {
  run docker run --rm \
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
      /usr/local/bin/entrypoint.sh /bin/bash -c "set -euo pipefail; echo \"\$(id -un):\$(id -gn):\$(id -u):\$(id -g)\""
    '
  [ "$status" -eq 0 ]
  result="$(printf '%s\n' "${output}" | tail -n 1)"
  IFS=':' read -r user group uid gid <<<"${result}"
  [ "${user}" = "hostuser" ]
  [ "${group}" = "hostuser" ]
  [ "${uid}" -eq 1000 ]
  [ "${gid}" -eq 1000 ]
}

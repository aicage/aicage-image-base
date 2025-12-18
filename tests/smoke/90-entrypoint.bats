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

@test "docker group exists and user is a member" {
  run docker run --rm \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    /bin/bash -c '
      set -euo pipefail
      getent group docker | cut -d: -f3; id -nG
    '
  [ "$status" -eq 0 ]
  mapfile -t lines <<<"${output}"
  gid="${lines[0]}"
  groups="${lines[1]}"
  [[ -n "${gid}" ]]
  [[ " ${groups} " == *" docker "* ]]
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

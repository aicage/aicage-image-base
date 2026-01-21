#!/usr/bin/env bats

cleanup_mount_dir() {
  local dir="$1"
  docker run --rm \
    -v "${dir}:/cleanup" \
    --entrypoint /bin/bash \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -c '
      set -euo pipefail
      for entry in /cleanup/.* /cleanup/*; do
        name="$(basename "$entry")"
        [ "$name" = "." ] || [ "$name" = ".." ] && continue
        rm -rf "$entry"
      done
    ' >/dev/null 2>&1 || true
  rm -rf "${dir}" >/dev/null 2>&1 || true
}

@test "gitconfig mount is symlinked into home and git config" {
  host_dir="$(mktemp -d)"
  trap 'cleanup_mount_dir "${host_dir}"' RETURN
  chmod 755 "${host_dir}"
  printf '[user]\n  name = example\n' >"${host_dir}/gitconfig"
  chmod 644 "${host_dir}/gitconfig"

  run docker run --rm \
    -v "${host_dir}:/aicage/host:ro" \
    --env AICAGE_UID=1234 \
    --env AICAGE_GID=2345 \
    --env AICAGE_USER=demo \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -c '
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

@test "gitconfig mount is symlinked into root home" {
  host_dir="$(mktemp -d)"
  trap 'cleanup_mount_dir "${host_dir}"' RETURN
  chmod 755 "${host_dir}"
  printf '[user]\n  name = example\n' >"${host_dir}/gitconfig"
  chmod 644 "${host_dir}/gitconfig"

  run docker run --rm \
    -v "${host_dir}:/aicage/host:ro" \
    --env AICAGE_UID=0 \
    --env AICAGE_GID=0 \
    --env AICAGE_USER=demo \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -c '
      set -euo pipefail
      [[ -L /root/.gitconfig ]]
      [[ -L /root/.config/git/config ]]
      [[ $(readlink -f /root/.gitconfig) == "/aicage/host/gitconfig" ]]
      [[ $(readlink -f /root/.config/git/config) == "/aicage/host/gitconfig" ]]
      cat /root/.gitconfig
    '
  [ "$status" -eq 0 ]
  [[ "$output" == *"name = example"* ]]
}

@test "gnupg and ssh mounts are symlinked into home" {
  host_dir="$(mktemp -d)"
  trap 'cleanup_mount_dir "${host_dir}"' RETURN
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
    -c '
      set -euo pipefail
      [[ -L ${HOME}/.gnupg ]]
      [[ -L ${HOME}/.ssh ]]
      [[ $(readlink -f ${HOME}/.gnupg) == "/aicage/host/gnupg" ]]
      [[ $(readlink -f ${HOME}/.ssh) == "/aicage/host/ssh" ]]
      cat ${HOME}/.gnupg/config
      cat ${HOME}/.ssh/known_hosts
    '
  [ "$status" -eq 0 ]
  [[ "$output" == *"gnupg-data"* ]]
  [[ "$output" == *"ssh-data"* ]]
}

@test "gnupg and ssh mounts are symlinked into root home" {
  host_dir="$(mktemp -d)"
  trap 'cleanup_mount_dir "${host_dir}"' RETURN
  chmod 755 "${host_dir}"
  mkdir -p "${host_dir}/gnupg" "${host_dir}/ssh"
  chmod 755 "${host_dir}/gnupg" "${host_dir}/ssh"
  printf 'gnupg-data\n' >"${host_dir}/gnupg/config"
  printf 'ssh-data\n' >"${host_dir}/ssh/known_hosts"
  chmod 644 "${host_dir}/gnupg/config" "${host_dir}/ssh/known_hosts"

  run docker run --rm \
    -v "${host_dir}:/aicage/host:ro" \
    --env AICAGE_UID=0 \
    --env AICAGE_GID=0 \
    --env AICAGE_USER=demo \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -c '
      set -euo pipefail
      [[ -L /root/.gnupg ]]
      [[ -L /root/.ssh ]]
      [[ $(readlink -f /root/.gnupg) == "/aicage/host/gnupg" ]]
      [[ $(readlink -f /root/.ssh) == "/aicage/host/ssh" ]]
      cat /root/.gnupg/config
      cat /root/.ssh/known_hosts
    '
  [ "$status" -eq 0 ]
  [[ "$output" == *"gnupg-data"* ]]
  [[ "$output" == *"ssh-data"* ]]
}

@test "agent config mounts are symlinked into home" {
  host_dir="$(mktemp -d)"
  trap 'cleanup_mount_dir "${host_dir}"' RETURN
  chmod 755 "${host_dir}"
  mkdir -p "${host_dir}/claude"
  printf 'claude-dir\n' >"${host_dir}/claude/config"
  printf 'claude-file\n' >"${host_dir}/claude.json"
  chmod 644 "${host_dir}/claude/config" "${host_dir}/claude.json"

  run docker run --rm \
    -v "${host_dir}/claude:/aicage/agent-config/.claude:ro" \
    -v "${host_dir}/claude.json:/aicage/agent-config/.claude.json:ro" \
    --env AICAGE_UID=1234 \
    --env AICAGE_GID=2345 \
    --env AICAGE_USER=demo \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -c '
      set -euo pipefail
      [[ -L ${HOME}/.claude ]]
      [[ -L ${HOME}/.claude.json ]]
      [[ $(readlink -f ${HOME}/.claude) == "/aicage/agent-config/.claude" ]]
      [[ $(readlink -f ${HOME}/.claude.json) == "/aicage/agent-config/.claude.json" ]]
      cat ${HOME}/.claude/config
      cat ${HOME}/.claude.json
    '
  [ "$status" -eq 0 ]
  [[ "$output" == *"claude-dir"* ]]
  [[ "$output" == *"claude-file"* ]]
}

@test "skel is not copied when /home is a mountpoint" {
  host_dir="$(mktemp -d)"
  trap 'cleanup_mount_dir "${host_dir}"' RETURN
  mkdir -p "${host_dir}/demo"
  chmod 755 "${host_dir}" "${host_dir}/demo"

  run docker run --rm \
    -v "${host_dir}:/home" \
    --entrypoint /bin/bash \
    --env AICAGE_UID=1234 \
    --env AICAGE_GID=2345 \
    --env AICAGE_USER=demo \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -c '
      set -euo pipefail
      mkdir -p /etc/skel
      printf "skel\n" >/etc/skel/.skel_test
      /usr/local/bin/entrypoint.sh -c "set -euo pipefail; test ! -e \"\$HOME/.skel_test\""
    '
  [ "$status" -eq 0 ]
}

@test "skel is copied when home exists and is not a mountpoint" {
  host_dir="$(mktemp -d)"
  trap 'cleanup_mount_dir "${host_dir}"' RETURN

  run docker run --rm \
    -v "${host_dir}:/home/demo/work" \
    --entrypoint /bin/bash \
    --env AICAGE_UID=1234 \
    --env AICAGE_GID=2345 \
    --env AICAGE_USER=demo \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -c '
      set -euo pipefail
      mkdir -p /etc/skel
      printf "skel\n" >/etc/skel/.skel_test
      /usr/local/bin/entrypoint.sh -c "set -euo pipefail; test -e \"\$HOME/.skel_test\""
    '
  [ "$status" -eq 0 ]
}

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

@test "home file mount is directly available in AICAGE_HOME" {
  host_dir="$(mktemp -d)"
  trap 'cleanup_mount_dir "${host_dir}"' RETURN
  chmod 755 "${host_dir}"
  printf 'file-data\n' >"${host_dir}/.aicage-test-file"
  chmod 644 "${host_dir}/.aicage-test-file"

  run docker run --rm \
    --env AICAGE_WORKSPACE=/workspace \
    -v "${host_dir}/.aicage-test-file:/home/hoster/.aicage-test-file:ro" \
    --env AICAGE_HOST_IS_LINUX=true \
    --env AICAGE_UID=1234 \
    --env AICAGE_GID=2345 \
    --env AICAGE_HOST_USER=hoster \
    --env AICAGE_HOME=/home/hoster \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -c '
      set -euo pipefail
      [[ ! -L "${AICAGE_HOME}/.aicage-test-file" ]]
      cat "${AICAGE_HOME}/.aicage-test-file"
    '
  [ "$status" -eq 0 ]
  [[ "$output" == *"file-data"* ]]
}

@test "home file mount on non-linux host is directly available in AICAGE_HOME" {
  host_dir="$(mktemp -d)"
  trap 'cleanup_mount_dir "${host_dir}"' RETURN
  chmod 755 "${host_dir}"
  printf 'file-data\n' >"${host_dir}/.aicage-test-file"
  chmod 644 "${host_dir}/.aicage-test-file"

  run docker run --rm \
    --env AICAGE_WORKSPACE=/workspace \
    -v "${host_dir}/.aicage-test-file:/mnt/d/Users/hoster/.aicage-test-file:ro" \
    --env AICAGE_HOST_USER=hoster \
    --env AICAGE_HOME=/mnt/d/Users/hoster \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -c '
      set -euo pipefail
      [[ -L /root/.aicage-test-file ]]
      [[ $(readlink -f /root/.aicage-test-file) == "/mnt/d/Users/hoster/.aicage-test-file" ]]
      [[ ! -L "${AICAGE_HOME}/.aicage-test-file" ]]
      cat /root/.aicage-test-file
    '
  [ "$status" -eq 0 ]
  [[ "$output" == *"file-data"* ]]
}

@test "home file mount on non-linux host replaces existing /root file" {
  host_dir="$(mktemp -d)"
  trap 'cleanup_mount_dir "${host_dir}"' RETURN
  chmod 755 "${host_dir}"
  printf 'host-data\n' >"${host_dir}/.aicage-test-file"
  chmod 644 "${host_dir}/.aicage-test-file"

  run docker run --rm \
    --entrypoint /bin/bash \
    --env AICAGE_WORKSPACE=/workspace \
    -v "${host_dir}/.aicage-test-file:/mnt/d/Users/hoster/.aicage-test-file:ro" \
    --env AICAGE_HOST_USER=hoster \
    --env AICAGE_HOME=/mnt/d/Users/hoster \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -c '
      set -euo pipefail
      printf "image-data\n" >/root/.aicage-test-file
      /usr/local/bin/entrypoint.sh -c "
        set -euo pipefail
        [[ -L /root/.aicage-test-file ]]
        [[ \$(readlink -f /root/.aicage-test-file) == /mnt/d/Users/hoster/.aicage-test-file ]]
        [[ \$(cat /root/.aicage-test-file) == host-data ]]
        ls /root/.aicage-test-file.* >/dev/null
      "
    '
  [ "$status" -eq 0 ]
}

@test "home dir mounts are directly available in AICAGE_HOME" {
  host_dir="$(mktemp -d)"
  trap 'cleanup_mount_dir "${host_dir}"' RETURN
  chmod 755 "${host_dir}"
  mkdir -p "${host_dir}/dir-a" "${host_dir}/dir-b"
  chmod 755 "${host_dir}/dir-a" "${host_dir}/dir-b"
  printf 'dir-a\n' >"${host_dir}/dir-a/config"
  printf 'dir-b\n' >"${host_dir}/dir-b/known_hosts"
  chmod 644 "${host_dir}/dir-a/config" "${host_dir}/dir-b/known_hosts"

  run docker run --rm \
    --env AICAGE_WORKSPACE=/workspace \
    -v "${host_dir}/dir-a:/home/hoster/.aicage-test-dir-a:ro" \
    -v "${host_dir}/dir-b:/home/hoster/.aicage-test-dir-b:ro" \
    --env AICAGE_HOST_IS_LINUX=true \
    --env AICAGE_UID=5678 \
    --env AICAGE_GID=6789 \
    --env AICAGE_HOST_USER=hoster \
    --env AICAGE_HOME=/home/hoster \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -c '
      set -euo pipefail
      [[ ! -L "${AICAGE_HOME}/.aicage-test-dir-a" ]]
      [[ ! -L "${AICAGE_HOME}/.aicage-test-dir-b" ]]
      cat "${AICAGE_HOME}/.aicage-test-dir-a/config"
      cat "${AICAGE_HOME}/.aicage-test-dir-b/known_hosts"
    '
  [ "$status" -eq 0 ]
  [[ "$output" == *"dir-a"* ]]
  [[ "$output" == *"dir-b"* ]]
}

@test "home dir mounts on non-linux host are directly available in AICAGE_HOME" {
  host_dir="$(mktemp -d)"
  trap 'cleanup_mount_dir "${host_dir}"' RETURN
  chmod 755 "${host_dir}"
  mkdir -p "${host_dir}/dir-a" "${host_dir}/dir-b"
  chmod 755 "${host_dir}/dir-a" "${host_dir}/dir-b"
  printf 'dir-a\n' >"${host_dir}/dir-a/config"
  printf 'dir-b\n' >"${host_dir}/dir-b/known_hosts"
  chmod 644 "${host_dir}/dir-a/config" "${host_dir}/dir-b/known_hosts"

  run docker run --rm \
    --env AICAGE_WORKSPACE=/workspace \
    -v "${host_dir}/dir-a:/mnt/d/Users/hoster/.aicage-test-dir-a:ro" \
    -v "${host_dir}/dir-b:/mnt/d/Users/hoster/.aicage-test-dir-b:ro" \
    --env AICAGE_HOST_USER=hoster \
    --env AICAGE_HOME=/mnt/d/Users/hoster \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -c '
      set -euo pipefail
      [[ -L /root/.aicage-test-dir-a ]]
      [[ -L /root/.aicage-test-dir-b ]]
      [[ $(readlink -f /root/.aicage-test-dir-a) == "/mnt/d/Users/hoster/.aicage-test-dir-a" ]]
      [[ $(readlink -f /root/.aicage-test-dir-b) == "/mnt/d/Users/hoster/.aicage-test-dir-b" ]]
      [[ ! -L "${AICAGE_HOME}/.aicage-test-dir-a" ]]
      [[ ! -L "${AICAGE_HOME}/.aicage-test-dir-b" ]]
      cat /root/.aicage-test-dir-a/config
      cat /root/.aicage-test-dir-b/known_hosts
    '
  [ "$status" -eq 0 ]
  [[ "$output" == *"dir-a"* ]]
  [[ "$output" == *"dir-b"* ]]
}

@test "home dir and file mounts are directly available in AICAGE_HOME" {
  host_dir="$(mktemp -d)"
  trap 'cleanup_mount_dir "${host_dir}"' RETURN
  chmod 755 "${host_dir}"
  mkdir -p "${host_dir}/dir-a"
  printf 'dir-data\n' >"${host_dir}/dir-a/config"
  printf 'file-data\n' >"${host_dir}/file-a"
  chmod 755 "${host_dir}/dir-a"
  chmod 644 "${host_dir}/dir-a/config" "${host_dir}/file-a"

  run docker run --rm \
    --env AICAGE_WORKSPACE=/workspace \
    -v "${host_dir}/dir-a:/home/hoster/.aicage-test-dir:ro" \
    -v "${host_dir}/file-a:/home/hoster/.aicage-test-file:ro" \
    --env AICAGE_HOST_IS_LINUX=true \
    --env AICAGE_UID=4242 \
    --env AICAGE_GID=4243 \
    --env AICAGE_HOST_USER=hoster \
    --env AICAGE_HOME=/home/hoster \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -c '
      set -euo pipefail
      [[ ! -L "${AICAGE_HOME}/.aicage-test-dir" ]]
      [[ ! -L "${AICAGE_HOME}/.aicage-test-file" ]]
      cat "${AICAGE_HOME}/.aicage-test-dir/config"
      cat "${AICAGE_HOME}/.aicage-test-file"
    '
  [ "$status" -eq 0 ]
  [[ "$output" == *"dir-data"* ]]
  [[ "$output" == *"file-data"* ]]
}

@test "refuses to start when /home is a mountpoint" {
  host_dir="$(mktemp -d)"
  trap 'cleanup_mount_dir "${host_dir}"' RETURN
  mkdir -p "${host_dir}/demo"
  chmod 755 "${host_dir}" "${host_dir}/demo"

  run docker run --rm \
    --env AICAGE_WORKSPACE=/workspace \
    -v "${host_dir}:/home" \
    --entrypoint /bin/bash \
    --env AICAGE_HOST_IS_LINUX=true \
    --env AICAGE_UID=1234 \
    --env AICAGE_GID=2345 \
    --env AICAGE_HOME=/home/demo \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -c '
      set -euo pipefail
      /usr/local/bin/entrypoint.sh -c "set -euo pipefail; echo ok"
    '
  [ "$status" -eq 1 ]
  [[ "$output" == *"Refusing to start: home path or parent is a mountpoint:"* ]]
}

@test "refuses to start when /root is a mountpoint" {
  host_dir="$(mktemp -d)"
  trap 'cleanup_mount_dir "${host_dir}"' RETURN
  chmod 755 "${host_dir}"

  run docker run --rm \
    --env AICAGE_WORKSPACE=/workspace \
    -v "${host_dir}:/root" \
    --entrypoint /bin/bash \
    --env AICAGE_UID=1234 \
    --env AICAGE_GID=2345 \
    --env AICAGE_HOME=/home/demo \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -c '
      set -euo pipefail
      /usr/local/bin/entrypoint.sh -c "set -euo pipefail; echo ok"
    '
  [ "$status" -eq 1 ]
  [[ "$output" == *"Refusing to start: home path or parent is a mountpoint:"* ]]
}

@test "skel is copied when home exists and is not a mountpoint" {
  host_dir="$(mktemp -d)"
  trap 'cleanup_mount_dir "${host_dir}"' RETURN

  run docker run --rm \
    --env AICAGE_WORKSPACE=/workspace \
    -v "${host_dir}:/home/demo/work" \
    --entrypoint /bin/bash \
    --env AICAGE_HOST_IS_LINUX=true \
    --env AICAGE_UID=1234 \
    --env AICAGE_GID=2345 \
    --env AICAGE_HOME=/home/demo \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -c '
      set -euo pipefail
      mkdir -p /etc/skel
      printf "skel\n" >/etc/skel/.skel_test
      /usr/local/bin/entrypoint.sh -c "set -euo pipefail; test -e \"\$HOME/.skel_test\""
    '
  [ "$status" -eq 0 ]
}

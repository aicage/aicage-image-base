#!/usr/bin/env bash
set -euo pipefail

# AICAGE entrypoint
# Required env vars (best-effort defaults are applied):
# - AICAGE_WORKSPACE: container working directory (defaults to /workspace)
# - AICAGE_ENTRYPOINT_CMD: command to exec (defaults to bash)
# - AICAGE_HOST_USER: host username (required on Linux)
# - AICAGE_UID/AICAGE_GID: linux host user mapping (required on Linux)
# - AICAGE_HOME: posix host home path
# - AICAGE_HOST_IS_LINUX: set to non-empty on Linux hosts; empty otherwise

AICAGE_WORKSPACE="${AICAGE_WORKSPACE:-/workspace}"

if [[ -z "${AICAGE_HOST_IS_LINUX:-}" ]]; then
  TARGET_USER="root"
  AICAGE_UID="0"
  AICAGE_GID="0"
else
  TARGET_USER="${AICAGE_HOST_USER:-aicage}"
  AICAGE_UID="${AICAGE_UID:-1000}"
  AICAGE_GID="${AICAGE_GID:-1000}"
fi

if [[ -z "${AICAGE_HOME:-}" ]]; then
  if [[ "${TARGET_USER}" == "root" ]]; then
    AICAGE_HOME="/root"
  else
    AICAGE_HOME="/home/${TARGET_USER}"
  fi
fi

is_mountpoint() {
  local path="$1"
  local parent
  parent="$(dirname "$path")"
  # different device id than parent ⇒ mount (bind mount or volume)
  [ "$(stat -c %d "$path" 2>/dev/null)" != "$(stat -c %d "$parent" 2>/dev/null)" ]
}

ensure_home_is_not_mounted() {
  local path="$1"
  local current
  current="$path"
  while true; do
    if [ -e "$current" ] && is_mountpoint "$current"; then
      echo "Refusing to start: home path or parent is a mountpoint: ${current}" >&2
      exit 1
    fi
    if [ "$current" = "/" ]; then
      break
    fi
    current="$(dirname "$current")"
  done
}

copy_skel_if_safe() {
  local home_dir="$1"
  local uid="$2"
  local gid="$3"
  local skel_dir="/etc/skel"

  # do nothing if home is a mount
  if is_mountpoint "$home_dir"; then
    return 0
  fi

  # do nothing if skel missing or empty
  [ -d "$skel_dir" ] || return 0
  [ -n "$(ls -A "$skel_dir" 2>/dev/null)" ] || return 0

  for src in "$skel_dir"/.* "$skel_dir"/*; do
    local name dst
    [ -e "$src" ] || continue
    name="$(basename "$src")"
    [ "$name" = "." ] || [ "$name" = ".." ] && continue

    dst="$home_dir/$name"
    if [ ! -e "$dst" ]; then
      cp -a "$src" "$home_dir/"
      # chown only what we copied
      chown -hR "$uid:$gid" "$dst" 2>/dev/null || chown -R "$uid:$gid" "$dst"
    fi
  done
}

set_target_env() {
  export HOME="$1"
  export USER="$2"
  export PATH="${HOME}/.local/bin:${PATH}"
}

list_home_mount_points() {
  local mountinfo line mount_point
  mountinfo="/proc/self/mountinfo"
  [ -r "${mountinfo}" ] || return 0

  while IFS= read -r line; do
    set -- ${line}
    mount_point="$5"
    if [[ "${mount_point}" == "${AICAGE_HOME}" || "${mount_point}" == "${AICAGE_HOME}/"* ]]; then
      printf '%s\n' "${mount_point}"
    fi
  done < "${mountinfo}" | sort -u
}

normalize_mount_path() {
  local path="$1"
  if [ -d "${path}" ]; then
    printf '%s/\n' "${path%/}"
  else
    printf '%s\n' "${path}"
  fi
}

filter_nested_mount_points() {
  local i j
  local is_nested
  local -a mount_points

  mount_points=("$@")
  for i in "${!mount_points[@]}"; do
    mount_points[i]="$(normalize_mount_path "${mount_points[i]}")"
  done

  for i in "${!mount_points[@]}"; do
    [ -n "${mount_points[i]}" ] || continue
    is_nested=0
    for j in "${!mount_points[@]}"; do
      [ -n "${mount_points[j]}" ] || continue
      if [[ "${i}" -eq "${j}" ]]; then
        continue
      fi
      if [[ "${mount_points[i]}" == "${mount_points[j]}"* ]]; then
        is_nested=1
        break
      fi
    done
    if [[ "${is_nested}" -eq 0 ]]; then
      printf '%s\n' "${mount_points[i]}"
    fi
  done
}

ensure_home_mount_parents_owned() {
  local uid="$1"
  local gid="$2"
  local current mount_point
  local -a mount_points mount_points_filtered
  local -A visited_dirs
  mapfile -t mount_points < <(list_home_mount_points)
  mapfile -t mount_points_filtered < <(filter_nested_mount_points "${mount_points[@]}")
  visited_dirs=()

  if [ -d "${AICAGE_HOME}" ] && ! is_mountpoint "${AICAGE_HOME}"; then
    chown "${uid}:${gid}" "${AICAGE_HOME}"
  fi

  for mount_point in "${mount_points_filtered[@]}"; do
    current="$(dirname "${mount_point}")"
    while [[ "${current}" == "${AICAGE_HOME}" || "${current}" == "${AICAGE_HOME}/"* ]]; do
      if [[ "${current}" == "${AICAGE_HOME}" ]]; then
        break
      fi
      if [[ -n "${visited_dirs[$current]:-}" ]]; then
        current="$(dirname "${current}")"
        continue
      fi
      visited_dirs["$current"]=1
      if is_mountpoint "${current}"; then
        current="$(dirname "${current}")"
        continue
      fi
      if [ -d "${current}" ]; then
        chown "${uid}:${gid}" "${current}"
      fi
      current="$(dirname "${current}")"
    done
  done
}

setup_user_and_group() {
  local existing_user_name existing_user_uid existing_group_name

  existing_user_uid="$(getent passwd "${TARGET_USER}" | cut -d: -f3 || true)"
  if [[ -n "${existing_user_uid}" && "${existing_user_uid}" != "${AICAGE_UID}" ]]; then
    userdel -r "${TARGET_USER}" 2>/dev/null
  fi

  existing_user_name="$(getent passwd "${AICAGE_UID}" | cut -d: -f1 || true)"
  if [[ -n "${existing_user_name}" && "${existing_user_name}" != "${TARGET_USER}" ]]; then
    userdel -r "${existing_user_name}" 2>/dev/null
  fi

  existing_group_name="$(getent group "${AICAGE_GID}" | cut -d: -f1 || true)"
  if [[ -n "${existing_group_name}" && "${existing_group_name}" != "${TARGET_USER}" && "${existing_group_name}" != "docker" ]]; then
    groupdel "${existing_group_name}"
  fi

  if ! getent group "${AICAGE_GID}" >/dev/null; then
    groupadd -g "${AICAGE_GID}" "${TARGET_USER}"
  fi

  if [[ -d "${AICAGE_HOME}" ]]; then
    useradd --no-create-home -u "${AICAGE_UID}" -g "${AICAGE_GID}" -d "${AICAGE_HOME}" -s /bin/bash "${TARGET_USER}"
  else
    useradd --create-home -u "${AICAGE_UID}" -g "${AICAGE_GID}" -d "${AICAGE_HOME}" -s /bin/bash "${TARGET_USER}"
  fi
  TARGET_HOME="${AICAGE_HOME}"

  copy_skel_if_safe "${AICAGE_HOME}" "${AICAGE_UID}" "${AICAGE_GID}"
}

setup_docker_group() {
  local docker_sock docker_gid_group docker_sock_gid existing_docker_gid_group

  docker_sock="/var/run/docker.sock"
  docker_gid_group=""
  if [[ -S "${docker_sock}" ]]; then
    docker_sock_gid="$(stat -c '%g' "${docker_sock}")"
    existing_docker_gid_group="$(getent group "${docker_sock_gid}" | cut -d: -f1 || true)"
    if [[ -n "${existing_docker_gid_group}" ]]; then
      docker_gid_group="${existing_docker_gid_group}"
    elif getent group docker >/dev/null; then
      groupmod -g "${docker_sock_gid}" docker
      docker_gid_group="docker"
    else
      groupadd -g "${docker_sock_gid}" docker
      docker_gid_group="docker"
    fi
  fi

  if [[ -n "${docker_gid_group}" ]]; then
    usermod -aG "${docker_gid_group}" "${TARGET_USER}"
  fi
}

setup_workspace() {
  if [ -e "${AICAGE_WORKSPACE}" ] && ! is_mountpoint "${AICAGE_WORKSPACE}"; then
    chown "${AICAGE_UID}:${AICAGE_GID}" "${AICAGE_WORKSPACE}"
  fi
  ensure_home_mount_parents_owned "${AICAGE_UID}" "${AICAGE_GID}"
}

ensure_home_is_not_mounted "/home"
ensure_home_is_not_mounted "/root"

# set up user and group
if [[ "${TARGET_USER}" == "root" ]]; then
  TARGET_HOME="/root"
else
  setup_user_and_group
  setup_docker_group
  setup_workspace
fi

ensure_home_is_not_mounted "${AICAGE_HOME}"
set_target_env "${TARGET_HOME}" "${TARGET_USER}"

if [[ ! -e "${AICAGE_WORKSPACE}" ]]; then
  mkdir -p "${AICAGE_WORKSPACE}"
fi
cd "${AICAGE_WORKSPACE}"

: "${AICAGE_ENTRYPOINT_CMD:=bash}"

if [[ "${TARGET_USER}" == "root" ]]; then
  exec "${AICAGE_ENTRYPOINT_CMD}" "$@"
else
  # switch to user
  exec gosu "${AICAGE_UID}" "${AICAGE_ENTRYPOINT_CMD}" "$@"
fi

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

AICAGE_USER_HOME_MOUNTS_DIR="/aicage/user-home"

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

replace_symlink() {
  local target_path="$1"
  local link_path="$2"

  if [[ -e "${link_path}" || -L "${link_path}" ]]; then
    local timestamp backup_path
    timestamp="$(date +%Y%m%d%H%M%S%N)"
    backup_path="${link_path}.${timestamp}"
    mv "${link_path}" "${backup_path}"
  fi
  ln -sfn "${target_path}" "${link_path}"
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
  local mountinfo
  mountinfo="/proc/self/mountinfo"
  [ -r "${mountinfo}" ] || return 0
  # /proc/self/mountinfo format:
  # field 5 is the mount point path
  # we only want mount points under /aicage/user-home
  awk -v base="${AICAGE_USER_HOME_MOUNTS_DIR}" '$5 ~ "^"base {print $5}' "${mountinfo}"
}

setup_home_mount_links() {
  local rel_path mount_point host_link root_link
  [ -d "${AICAGE_USER_HOME_MOUNTS_DIR}" ] || return 0

  while IFS= read -r mount_point; do
    if [[ "${mount_point}" == "${AICAGE_USER_HOME_MOUNTS_DIR}" ]]; then
      continue
    fi
    rel_path="${mount_point#${AICAGE_USER_HOME_MOUNTS_DIR}/}"
    host_link="${AICAGE_HOME}/${rel_path}"
    mkdir -p "$(dirname "${host_link}")"
    replace_symlink "${mount_point}" "${host_link}"

    if [[ -z "${AICAGE_HOST_IS_LINUX:-}" ]]; then
      root_link="${TARGET_HOME}/${rel_path}"
      mkdir -p "$(dirname "${root_link}")"
      replace_symlink "${mount_point}" "${root_link}"
    fi
  done < <(list_home_mount_points)
}

setup_user_and_group() {
  local existing_group_name existing_user_name existing_user_uid target_group_gid

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
    existing_group_name=""
  fi

  if getent group "${TARGET_USER}" >/dev/null; then
    target_group_gid="$(getent group "${TARGET_USER}" | cut -d: -f3)"
    if [[ "${target_group_gid}" != "${AICAGE_GID}" && "${existing_group_name}" != "docker" ]]; then
      groupmod -g "${AICAGE_GID}" "${TARGET_USER}"
    fi
  elif [[ -z "${existing_group_name}" ]]; then
    groupadd -g "${AICAGE_GID}" "${TARGET_USER}"
  fi
}

setup_home() {
  local create_home copy_skel home_parent home_dir home_parent_is_mount home_dir_is_mount

  create_home="--no-create-home"
  copy_skel="false"
  home_parent="/home"
  home_dir="/home/${TARGET_USER}"
  home_parent_is_mount="false"
  home_dir_is_mount="false"

  if [ -d "${home_parent}" ] && is_mountpoint "${home_parent}"; then
    home_parent_is_mount="true"
  fi

  if [ -d "${home_dir}" ] && is_mountpoint "${home_dir}"; then
    home_dir_is_mount="true"
  fi

  if [[ "${home_parent_is_mount}" == "true" || "${home_dir_is_mount}" == "true" ]]; then
    create_home="--no-create-home"
    copy_skel="false"
  elif [ -d "${home_dir}" ]; then
    create_home="--no-create-home"
    copy_skel="true"
  else
    create_home="--create-home"
    copy_skel="false"
  fi

  if ! getent passwd "${AICAGE_UID}" >/dev/null; then
    useradd "${create_home}" -u "${AICAGE_UID}" -g "${AICAGE_GID}" -s /bin/bash "${TARGET_USER}"
  fi

  TARGET_USER="$(getent passwd "${AICAGE_UID}" | cut -d: -f1)"
  TARGET_HOME="$(getent passwd "${AICAGE_UID}" | cut -d: -f6)"
  TARGET_HOME="${TARGET_HOME:-/home/${TARGET_USER}}"

  if [[ "${copy_skel}" == "true" ]]; then
    copy_skel_if_safe "${TARGET_HOME}" "${AICAGE_UID}" "${AICAGE_GID}"
  fi
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
  if [ -e "${AICAGE_WORKSPACE}" ]; then
    chown "${AICAGE_UID}:${AICAGE_GID}" "${AICAGE_WORKSPACE}"
  fi
  if [ -d "${TARGET_HOME}" ]; then
    if ! is_mountpoint "/home" && ! is_mountpoint "${TARGET_HOME}"; then
      chown "${AICAGE_UID}:${AICAGE_GID}" "${TARGET_HOME}"
    fi
  fi
}

ensure_home_is_not_mounted "/home"
ensure_home_is_not_mounted "/root"

# set up user and group
if [[ "${TARGET_USER}" == "root" ]]; then
  TARGET_HOME="/root"
else
  setup_user_and_group
  setup_home
  setup_docker_group
  setup_workspace
fi

AICAGE_HOME="${AICAGE_HOME:-${TARGET_HOME}}"
ensure_home_is_not_mounted "${AICAGE_HOME}"
setup_home_mount_links
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

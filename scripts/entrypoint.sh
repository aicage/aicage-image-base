#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${AICAGE_WORKSPACE:-}" ]]; then
  AICAGE_WORKSPACE="/workspace"
fi

is_mountpoint() {
  local path="$1"
  local parent
  parent="$(dirname "$path")"
  # different device id than parent ⇒ mount (bind mount or volume)
  [ "$(stat -c %d "$path" 2>/dev/null)" != "$(stat -c %d "$parent" 2>/dev/null)" ]
}

replace_symlink() {
  local target_path="$1"
  local link_path="$2"

  if [[ -e "${link_path}" || -L "${link_path}" ]]; then
    rm -rf "${link_path}"
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

setup_agent_config_links() {
  local config_root target_path
  config_root="/aicage/agent-config"

  if [[ ! -d "${config_root}" ]]; then
    return 0
  fi

  while IFS= read -r mount_point; do
    if [[ "${mount_point}" == "${config_root}" ]]; then
      continue
    fi
    target_path="${TARGET_HOME}/${mount_point#${config_root}/}"
    mkdir -p "$(dirname "${target_path}")"
    replace_symlink "${mount_point}" "${target_path}"
  done < <(awk '{print $5}' /proc/self/mountinfo | awk -v root="${config_root}" '$0 ~ "^"root"/"')
}

setup_host_symlinks() {
  if [[ -e "/aicage/host/gitconfig" ]]; then
    mkdir -p "${TARGET_HOME}/.config/git"
    replace_symlink "/aicage/host/gitconfig" "${TARGET_HOME}/.gitconfig"
    replace_symlink "/aicage/host/gitconfig" "${TARGET_HOME}/.config/git/config"
  fi

  if [[ -e "/aicage/host/gnupg" ]]; then
    replace_symlink "/aicage/host/gnupg" "${TARGET_HOME}/.gnupg"
  fi

  if [[ -e "/aicage/host/ssh" ]]; then
    replace_symlink "/aicage/host/ssh" "${TARGET_HOME}/.ssh"
  fi
}

setup_user_and_group() {
  local existing_group_name existing_user_name

  existing_group_name="$(getent group "${TARGET_GID}" | cut -d: -f1 || true)"
  if [[ -n "${existing_group_name}" && "${existing_group_name}" != "${TARGET_USER}" && "${existing_group_name}" != "docker" ]]; then
    if ! getent group "${TARGET_USER}" >/dev/null; then
      groupmod -n "${TARGET_USER}" "${existing_group_name}"
    fi
  fi

  if ! getent group "${TARGET_GID}" >/dev/null; then
    groupadd -g "${TARGET_GID}" "${TARGET_USER}"
  fi

  existing_user_name="$(getent passwd "${TARGET_UID}" | cut -d: -f1 || true)"
  if [[ -n "${existing_user_name}" && "${existing_user_name}" != "${TARGET_USER}" ]]; then
    if ! getent passwd "${TARGET_USER}" >/dev/null; then
      usermod -l "${TARGET_USER}" "${existing_user_name}"
    fi
  fi
}

setup_home() {
  local home_parent home_dir home_parent_is_mount home_dir_is_mount

  CREATE_HOME="--no-create-home"
  COPY_SKEL="false"
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
    CREATE_HOME="--no-create-home"
    COPY_SKEL="false"
  elif [ -d "${home_dir}" ]; then
    CREATE_HOME="--no-create-home"
    COPY_SKEL="true"
  else
    CREATE_HOME="--create-home"
    COPY_SKEL="false"
  fi

  if ! getent passwd "${TARGET_UID}" >/dev/null; then
    useradd "${CREATE_HOME}" -u "${TARGET_UID}" -g "${TARGET_GID}" -s /bin/bash "${TARGET_USER}"
  fi

  TARGET_USER="$(getent passwd "${TARGET_UID}" | cut -d: -f1)"
  TARGET_HOME="$(getent passwd "${TARGET_UID}" | cut -d: -f6)"
  TARGET_HOME="${TARGET_HOME:-/home/${TARGET_USER}}"

  if [[ "${COPY_SKEL}" == "true" ]]; then
    copy_skel_if_safe "${TARGET_HOME}" "${TARGET_UID}" "${TARGET_GID}"
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
  mkdir -p "${AICAGE_WORKSPACE}"
  chown "${TARGET_UID}:${TARGET_GID}" "${AICAGE_WORKSPACE}"
  if [[ "${AICAGE_WORKSPACE}" != "/workspace" ]]; then
    mkdir -p "/workspace"
    chown "${TARGET_UID}:${TARGET_GID}" "/workspace"
  fi
  if [ -d "${TARGET_HOME}" ]; then
    if ! is_mountpoint "/home" && ! is_mountpoint "${TARGET_HOME}"; then
      chown "${TARGET_UID}:${TARGET_GID}" "${TARGET_HOME}"
    fi
  fi
}

# set up user and group
TARGET_USER="${AICAGE_USER:-${USER:-aicage}}"
TARGET_UID="${AICAGE_UID:-${UID:-1000}}"
TARGET_GID="${AICAGE_GID:-${GID:-1000}}"

if [[ "${TARGET_USER}" == "root" ]]; then
  TARGET_UID="0"
  TARGET_GID="0"
fi

if [[ "${TARGET_UID}" == "0" ]]; then
  TARGET_USER="root"
fi

if [[ "${TARGET_USER}" == "root" ]]; then
  TARGET_HOME="/root"
  setup_workspace
else
  setup_user_and_group
  setup_home
  setup_docker_group
  setup_workspace
fi

setup_agent_config_links
setup_host_symlinks
set_target_env "${TARGET_HOME}" "${TARGET_USER}"

cd "${AICAGE_WORKSPACE}"

: "${AICAGE_ENTRYPOINT_CMD:=bash}"

if [[ "${TARGET_USER}" == "root" ]]; then
  exec "${AICAGE_ENTRYPOINT_CMD}" "$@"
else
  # switch to user
  exec gosu "${TARGET_UID}" "${AICAGE_ENTRYPOINT_CMD}" "$@"
fi

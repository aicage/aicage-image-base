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

# set up user and group
TARGET_UID="${AICAGE_UID:-${UID:-1000}}"
TARGET_GID="${AICAGE_GID:-${GID:-1000}}"
TARGET_USER="${AICAGE_USER:-${USER:-aicage}}"

if [[ "${TARGET_UID}" == "0" ]]; then
  exec "$@"
fi

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

# add user to docker group if present
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

# set up workspace folder
mkdir -p "${AICAGE_WORKSPACE}"
chown "${TARGET_UID}:${TARGET_GID}" "${AICAGE_WORKSPACE}"
if [ -d "${TARGET_HOME}" ]; then
  if ! is_mountpoint "/home" && ! is_mountpoint "${TARGET_HOME}"; then
    chown "${TARGET_UID}:${TARGET_GID}" "${TARGET_HOME}"
  fi
fi

AICAGE_AGENT_CONFIG_MOUNT="/aicage/agent-config"
if [[ -n "${AICAGE_AGENT_CONFIG_PATH:-}" ]]; then
  target_path="${AICAGE_AGENT_CONFIG_PATH}"
  if [[ "${target_path}" == "~/"* ]]; then
    target_path="${TARGET_HOME}/${target_path:2}"
  elif [[ "${target_path:0:1}" != "/" ]]; then
    target_path="${TARGET_HOME}/${target_path}"
  fi
  mkdir -p "$(dirname "${target_path}")"
  ln -sfn "${AICAGE_AGENT_CONFIG_MOUNT}" "${target_path}"
fi

if [[ -e "/aicage/host/gitconfig" ]]; then
  mkdir -p "${TARGET_HOME}/.config/git"
  ln -sfn "/aicage/host/gitconfig" "${TARGET_HOME}/.gitconfig"
  ln -sfn "/aicage/host/gitconfig" "${TARGET_HOME}/.config/git/config"
fi

if [[ -e "/aicage/host/gnupg" ]]; then
  ln -sfn "/aicage/host/gnupg" "${TARGET_HOME}/.gnupg"
fi

if [[ -e "/aicage/host/ssh" ]]; then
  ln -sfn "/aicage/host/ssh" "${TARGET_HOME}/.ssh"
fi

export HOME="${TARGET_HOME}"
export USER="${TARGET_USER}"
export PATH="${HOME}/.local/bin:${PATH}"

cd "${AICAGE_WORKSPACE}"

: "${AICAGE_ENTRYPOINT_CMD:=bash}"

# switch to user
exec gosu "${TARGET_UID}" "${AICAGE_ENTRYPOINT_CMD}" "$@"

#!/usr/bin/env bash
set -euo pipefail

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

if ! getent passwd "${TARGET_UID}" >/dev/null; then
  useradd -m -u "${TARGET_UID}" -g "${TARGET_GID}" -s /bin/bash "${TARGET_USER}"
fi

TARGET_USER="$(getent passwd "${TARGET_UID}" | cut -d: -f1)"
TARGET_HOME="$(getent passwd "${TARGET_UID}" | cut -d: -f6)"
TARGET_HOME="${TARGET_HOME:-/home/${TARGET_USER}}"

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
mkdir -p /workspace
chown "${TARGET_UID}:${TARGET_GID}" /workspace
chown -R "${TARGET_UID}:${TARGET_GID}" "${TARGET_HOME}"

TOOL_MOUNT="/aicage/tool-config"
if [[ -n "${AICAGE_TOOL_PATH:-}" ]]; then
  target_path="${AICAGE_TOOL_PATH}"
  if [[ "${target_path}" == "~/"* ]]; then
    target_path="${TARGET_HOME}/${target_path:2}"
  elif [[ "${target_path:0:1}" != "/" ]]; then
    target_path="${TARGET_HOME}/${target_path}"
  fi
  mkdir -p "$(dirname "${target_path}")"
  ln -sfn "${TOOL_MOUNT}" "${target_path}"
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

cd /workspace

# switch to user
exec gosu "${TARGET_UID}" "$@"

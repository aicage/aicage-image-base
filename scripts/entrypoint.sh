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
if [[ -n "${existing_group_name}" && "${existing_group_name}" != "${TARGET_USER}" ]]; then
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
if getent group docker >/dev/null; then
  usermod -aG docker "${TARGET_USER}"
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

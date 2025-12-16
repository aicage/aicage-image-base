#!/usr/bin/env bash
set -euo pipefail

# set up user and group
TARGET_UID="${AICAGE_UID:-${UID:-1000}}"
TARGET_GID="${AICAGE_GID:-${GID:-1000}}"
TARGET_USER="${AICAGE_USER:-${USER:-aicage}}"

if [[ "${TARGET_UID}" == "0" ]]; then
  exec "$@"
fi

if ! getent group "${TARGET_GID}" >/dev/null; then
  groupadd -g "${TARGET_GID}" "${TARGET_USER}"
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

resolve_target_path() {
  local raw="$1"
  if [[ "${raw}" == "~/"* ]]; then
    echo "${TARGET_HOME}/${raw:2}"
  else
    echo "${raw}"
  fi
}

link_optional_mount() {
  local mount_path="$1"
  local target_hint="$2"
  if [[ -z "${target_hint}" ]]; then
    return
  fi
  if [[ ! -e "${mount_path}" ]]; then
    return
  fi
  local target_path
  target_path="$(resolve_target_path "${target_hint}")"
  mkdir -p "$(dirname "${target_path}")"
  ln -sfn "${mount_path}" "${target_path}"
}

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

link_optional_mount "/aicage/host/gitconfig" "${AICAGE_GITCONFIG_TARGET:-}"
link_optional_mount "/aicage/host/gnupg" "${AICAGE_GNUPG_TARGET:-}"
link_optional_mount "/aicage/host/ssh" "${AICAGE_SSH_TARGET:-}"

export HOME="${TARGET_HOME}"
export USER="${TARGET_USER}"
export PATH="${HOME}/.local/bin:${PATH}"

cd /workspace

# switch to user
exec gosu "${TARGET_UID}" "$@"

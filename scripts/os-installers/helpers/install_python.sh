#!/usr/bin/env bash
set -euo pipefail

: "${PIPX_HOME:?PIPX_HOME is required}"
: "${PIPX_BIN_DIR:?PIPX_BIN_DIR is required}"

PIP_ARGS=()
if python3 -m pip help install 2>/dev/null | grep -q -- --break-system-packages; then
  PIP_ARGS+=(--break-system-packages)
fi

python3 -m pip install "${PIP_ARGS[@]}" --ignore-installed --upgrade pip setuptools wheel

# Alpine does not ship a pipx package; install via pip when missing.
if ! command -v pipx >/dev/null 2>&1; then
  python3 -m pip install "${PIP_ARGS[@]}" --no-cache-dir --upgrade pipx
fi

mkdir -p "${PIPX_HOME}" "${PIPX_BIN_DIR}"
PIPX_HOME=${PIPX_HOME} PIPX_BIN_DIR=${PIPX_BIN_DIR} pipx ensurepath

PIP_NO_CACHE_DIR=1 \
  PIPX_HOME=${PIPX_HOME} \
  PIPX_BIN_DIR=${PIPX_BIN_DIR} \
  pipx install uv \
    --pip-args="--no-cache-dir"

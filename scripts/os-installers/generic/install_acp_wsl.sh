#!/usr/bin/env bash
set -euo pipefail

arch="$(uname -m)"
case "${arch}" in
  x86_64) acp_wsl_arch="amd64" ;;
  aarch64) acp_wsl_arch="arm64" ;;
  *)
    echo "Unsupported architecture for acp-wsl: ${arch}" >&2
    exit 1
    ;;
esac

curl -fsSL \
  --retry 8 \
  --retry-all-errors \
  --retry-delay 2 \
  --max-time 600 \
  "https://github.com/aicage-dev/acp-wsl/releases/latest/download/acp-wsl-linux-${acp_wsl_arch}" \
  -o /usr/local/bin/acp-wsl

chmod 755 /usr/local/bin/acp-wsl
acp-wsl --version

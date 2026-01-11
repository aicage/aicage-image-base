#!/usr/bin/env bash
set -euo pipefail

# add retry and other params to reduce failure in pipelines
curl_wrapper() {
  curl -fsSL \
    --retry 8 \
    --retry-all-errors \
    --retry-delay 2 \
    --max-time 600 \
    "$@"
}

if ! command -v gosu >/dev/null 2>&1; then
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64) ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    *)
      echo "Unsupported architecture for gosu: $ARCH" >&2
      exit 1
      ;;
  esac

  GOSU_VERSION="$(curl_wrapper https://api.github.com/repos/tianon/gosu/releases/latest | jq -r '.tag_name')"
  url="https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-${ARCH}"
  curl_wrapper "${url}" -o /usr/local/bin/gosu
  chmod +x /usr/local/bin/gosu
fi

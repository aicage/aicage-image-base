#!/usr/bin/env bash
set -euo pipefail

case "$(uname -m)" in
  x86_64) NODE_DIST_ARCH="x64" ;;
  aarch64|arm64) NODE_DIST_ARCH="arm64" ;;
  *)
    echo "Unsupported host architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck source=../../scripts/common.sh
source "${ROOT_DIR}/scripts/common.sh"

NODEJS_VERSION="${NODEJS_VERSION:-}"
if [[ -z "${NODEJS_VERSION}" ]]; then
  NODEJS_VERSION="$(
    curl_wrapper https://nodejs.org/dist/index.json \
      | jq -r 'map(select(.lts != false)) | .[0].version'
  )"
  NODEJS_VERSION="${NODEJS_VERSION#v}"
fi

if [[ -z "${NODEJS_VERSION}" ]]; then
  echo "Unable to resolve latest Node.js LTS version" >&2
  exit 1
fi

if ! command -v node >/dev/null 2>&1; then
  curl_wrapper "https://nodejs.org/dist/v${NODEJS_VERSION}/node-v${NODEJS_VERSION}-linux-${NODE_DIST_ARCH}.tar.xz" \
    | tar -xJ -C /usr/local --strip-components=1
fi

ln -sf /usr/local/bin/node /usr/bin/node
ln -sf /usr/local/bin/npm /usr/bin/npm
ln -sf /usr/local/bin/npx /usr/bin/npx

npm config set prefix /usr/local

if command -v corepack >/dev/null 2>&1; then
  corepack enable
fi

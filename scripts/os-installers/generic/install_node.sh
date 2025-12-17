#!/usr/bin/env bash
set -euo pipefail

: "${TARGETARCH:?TARGETARCH is required}"

case "${TARGETARCH}" in
  amd64) NODE_DIST_ARCH="x64" ;;
  arm64) NODE_DIST_ARCH="arm64" ;;
  *)
    echo "Unsupported TARGETARCH ${TARGETARCH}" >&2
    exit 1
    ;;
esac

NODEJS_VERSION="${NODEJS_VERSION:-}"
if [[ -z "${NODEJS_VERSION}" ]]; then
  NODEJS_VERSION="$(
    curl -fsSL https://nodejs.org/dist/index.json \
      | jq -r 'map(select(.lts != false)) | .[0].version'
  )"
  NODEJS_VERSION="${NODEJS_VERSION#v}"
fi

if [[ -z "${NODEJS_VERSION}" ]]; then
  echo "Unable to resolve latest Node.js LTS version" >&2
  exit 1
fi

if ! command -v node >/dev/null 2>&1; then
  curl -fsSL "https://nodejs.org/dist/v${NODEJS_VERSION}/node-v${NODEJS_VERSION}-linux-${NODE_DIST_ARCH}.tar.xz" \
    | tar -xJ -C /usr/local --strip-components=1
fi

ln -sf /usr/local/bin/node /usr/bin/node
ln -sf /usr/local/bin/npm /usr/bin/npm
ln -sf /usr/local/bin/npx /usr/bin/npx

npm config set prefix /usr/local

if command -v corepack >/dev/null 2>&1; then
  corepack enable
fi

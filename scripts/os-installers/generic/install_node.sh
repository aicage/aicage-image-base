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

# add retry and other params to reduce failure in pipelines
curl_wrapper() {
  curl -fsSL \
    --retry 8 \
    --retry-all-errors \
    --retry-delay 2 \
    --max-time 600 \
    "$@"
}

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

# xdg-utils: provides xdg-open; needed by some npm-installed CLI agents (auth/docs URL open)
if ! command -v xdg-open >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update && apt-get install -y --no-install-recommends xdg-utils
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y xdg-utils
  elif command -v yum >/dev/null 2>&1; then
    yum install -y xdg-utils
  elif command -v zypper >/dev/null 2>&1; then
    zypper -n in xdg-utils
  elif command -v pacman >/dev/null 2>&1; then
    pacman -Sy --noconfirm xdg-utils
  elif command -v apk >/dev/null 2>&1; then
    apk add --no-cache xdg-utils
  fi
fi

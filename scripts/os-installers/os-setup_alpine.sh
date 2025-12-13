#!/bin/sh
set -eu

# Use --no-cache so we don't leave /var/cache/apk behind.
apk add --no-cache \
  bash \
  bash-completion \
  build-base \
  ca-certificates \
  curl \
  git \
  gnupg \
  gosu \
  jq \
  nano \
  openssh-client \
  py3-pip \
  python3 \
  py3-virtualenv \
  ripgrep \
  shadow \
  tar \
  tini \
  unzip \
  xz \
  zip

update-ca-certificates >/dev/null 2>&1 || true

# Alpine uses musl; "C.UTF-8" is always safe.
# If you want en_US.UTF-8 specifically, add musl-locales + musl-locales-lang.
apk add --no-cache musl-locales musl-locales-lang >/dev/null 2>&1 || true

cat > /etc/profile.d/locale.sh <<'LOCALE'
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
LOCALE

script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
helpers_dir="${script_dir}/helpers"
"${helpers_dir}/install_node_alpine.sh"
"${helpers_dir}/install_python.sh"

#!/usr/bin/env bash
set -euo pipefail

apk add --no-cache \
  bash \
  bash-completion \
  bats \
  bind-tools \
  ca-certificates \
  curl \
  file \
  git \
  gnupg \
  imagemagick \
  iproute2 \
  jq \
  less \
  nano \
  netcat-openbsd \
  openssh-client \
  p7zip \
  patch \
  procps \
  ripgrep \
  rsync \
  shadow \
  tar \
  time \
  tini \
  tree \
  tzdata \
  unzip \
  xz \
  yq \
  zip

update-ca-certificates >/dev/null 2>&1

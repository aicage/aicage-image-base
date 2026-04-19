#!/usr/bin/env bash
set -euo pipefail

apt-get install -y --no-install-recommends \
  bash \
  bash-completion \
  bats \
  ca-certificates \
  curl \
  dnsutils \
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
  p7zip-full \
  patch \
  ripgrep \
  rsync \
  tar \
  time \
  tini \
  tree \
  tzdata \
  unzip \
  xz-utils \
  yq \
  zip

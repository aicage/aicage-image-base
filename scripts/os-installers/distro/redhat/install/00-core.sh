#!/usr/bin/env bash
set -euo pipefail

dnf -y install \
  bash \
  bash-completion \
  bats \
  bind-utils \
  ca-certificates \
  curl \
  dnf-plugins-core \
  file \
  git \
  gnupg2 \
  iproute \
  jq \
  less \
  nano \
  nmap-ncat \
  openssh-clients \
  p7zip \
  patch \
  procps-ng \
  ripgrep \
  rsync \
  shadow-utils \
  tar \
  time \
  tini \
  tree \
  unzip \
  xz \
  zip

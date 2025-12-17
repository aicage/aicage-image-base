#!/usr/bin/env bash
set -euo pipefail

dnf -y install \
  glibc-all-langpacks \
  glibc-locale-source

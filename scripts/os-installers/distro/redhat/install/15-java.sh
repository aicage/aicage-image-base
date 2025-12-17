#!/usr/bin/env bash
set -euo pipefail

dnf -y install \
  ant \
  java-latest-openjdk-devel \
  maven \
  protobuf-compiler

# syntax=docker/dockerfile:1.7-labs
ARG BASE_IMAGE=ubuntu:24.04
ARG OS_INSTALLER=os-setup_debian.sh

FROM ${BASE_IMAGE} AS base

ARG TARGETARCH
ARG OS_INSTALLER

LABEL org.opencontainers.image.title="aicage-image-base" \
      org.opencontainers.image.description="Prebuilt base layer for agent images" \
      org.opencontainers.image.source="https://github.com/aicage/aicage-image-base" \
      org.opencontainers.image.licenses="Apache-2.0"

ENV DEBIAN_FRONTEND=noninteractive \
    AGENT_TARGETARCH=${TARGETARCH} \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    AICAGE_USER=aicage \
    AICAGE_UID=1000 \
    AICAGE_GID=1000 \
    PIPX_HOME=/opt/pipx \
    PIPX_BIN_DIR=/opt/pipx/bin \
    PATH="/opt/pipx/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin" \
    NPM_CONFIG_PREFIX=/usr/local

RUN --mount=type=bind,source=scripts/os-installers,target=/tmp/os-installers,readonly \
    /tmp/os-installers/${OS_INSTALLER}

COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh

# Use tini from PATH to work across distros (e.g. Alpine installs it in /sbin).
ENTRYPOINT ["tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["bash"]

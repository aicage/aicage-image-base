# Development Guide

This repository builds the base layers consumed by the agent images. Use it when adding a new base
OS, tweaking packages, or validating the base matrix.

## Prerequisites

- Docker (`docker --version`).
- QEMU/binfmt for multi-arch builds.
- Bats (`bats --version`) for smoke suites.
- Python 3.11+ with `pip install -r requirements-dev.txt` to pull lint/test tooling.
- `yq` is required by some scripts that parse `base.yaml`.

## Setup

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
```

## Repo layout

- `bases/<alias>/base.yaml` — Defines the upstream image and installer for each base.
- `Dockerfile` — Docker build entrypoint.
- `scripts/` — Build/test helpers.
- `tests/smoke/` — Bats suites for base images.
- `config.yaml` — Default repository, version, and platform settings.

## Configuration

Setting from `config.yaml`:

- `AICAGE_IMAGE_REGISTRY` (default `ghcr.io`)
- `AICAGE_IMAGE_BASE_REPOSITORY` (default `wuodan/aicage-image-base`)
- `AICAGE_VERSION` (default `dev`)
Base aliases come from folders under `bases/`.

## Build

```bash
# Build and load a single base
scripts/util/build.sh --base ubuntu

# Build all bases (platforms from config/environment)
scripts/util/build-all.sh
```

## Test

```bash
# Run smoke tests for all bases
scripts/test-all.sh
```

Smoke suites live in `tests/smoke/` (including subfolders); run individual files with
`bats tests/smoke/<path>.bats`.

## Adding a base

1. Create `bases/<alias>/base.yaml` with `base_image` and `os_installer`.
2. Add or adjust installer scripts if the base needs extra setup.
3. Update smoke coverage under `tests/smoke/` if the new base requires validation.
4. Document the new base in `README.md` if it should be visible to users.

## CI

`aicage-image-base/.github/workflows/build-<alias>.yml` builds and publishes base images (multi-arch)
on tags, producing `<alias>-<version>` and `<alias>-latest` tags.

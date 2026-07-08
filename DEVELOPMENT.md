# Development Guide

This repository builds the base layers consumed by the agent images. Use it when adding a new base
OS, tweaking packages, or validating the base matrix.

## Prerequisites

- Docker (`docker --version`).
- QEMU/binfmt for multi-arch builds.
- Bats (`bats --version`) for smoke suites.
- Python 3.11+ with `pip install -r requirements-dev.txt` to pull lint/test tooling.
- `yq` is required by some scripts that parse `base.yml`.

## Setup

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
```

## Repo layout

- `bases/<alias>/base.yml` — Defines the upstream image and installer for each base.
- `Dockerfile` — Docker build entrypoint.
- `scripts/` — Build/test helpers.
- `tests/bases/smoke/` — Bats suites for base images.
- `config.yml` — Default repository, version, and platform settings.

## Configuration

Setting from `config.yml`:

- `AICAGE_IMAGE_REGISTRY` (default `ghcr.io`)
- `AICAGE_IMAGE_BASE_REPOSITORY` (default `aicage/aicage-image-base`)
- `AICAGE_IMAGE_BASE_SOURCE_REPOSITORY` (default `aicage/aicage-image-base`)
- `AICAGE_VERSION` (default `dev`)
Base aliases come from folders under `bases/`.

## Fork Setup

To test releases from a fork:

1. Fork the repository.
2. Enable GitHub Actions on the fork.
3. Update `config.yml` for the fork namespace, for example:

   ```yaml
   AICAGE_IMAGE_BASE_REPOSITORY: aicage-dev/aicage-image-base
   AICAGE_IMAGE_BASE_SOURCE_REPOSITORY: aicage-dev/aicage-image-base
   ```

4. Push a Git tag to trigger the publish workflow. Prefer prerelease-style tags such as
   `0.1.0-beta.1` or `0.1.0-alpha.1`.
5. First release action run only:
   - One image building job likely fails with "cannot delete last/only tag of a package".
   - Wait until the action run ends with failure, but many other successful building jobs.
   - Then "Rerun failed jobs" in that action run.
6. Make the published GHCR package public.

## Build

```bash
# Build and load a single base
scripts/debug/build.sh --base ubuntu

# Build all bases (platforms from config/environment)
scripts/debug/build-all.sh
```

## Test

```bash
# Run smoke tests for all bases
scripts/test-all.sh
```

Smoke suites live in `tests/bases/smoke/` (including subfolders); run individual files with
`bats tests/bases/smoke/<path>.bats`.

## Adding a base

1. Create `bases/<alias>/base.yml` with `from_image` and `os_installer`.
2. Add or adjust installer scripts if the base needs extra setup.
3. Update smoke coverage under `tests/bases/smoke/` if the new base requires validation.
4. Document the new base in `README.md` if it should be visible to users.

## CI

`aicage-image-base/.github/workflows/build-<alias>.yml` builds and publishes base images (multi-arch)
on tags, producing `<alias>-<version>` and `<alias>` tags.

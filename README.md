# aicage-image-base

Base images for the aicage agent builds. Each base alias lives in `bases/<alias>/base.yaml` and is
built by the scripts in `scripts/`.

## Commands

- Build single base: `scripts/build.sh --base fedora --platform linux/amd64`
- Build all bases: `scripts/build-all.sh --platform linux/amd64`
- Smoke tests: `scripts/test-all.sh`

## CI

GitHub Actions runs `aicage-image-base/.github/workflows/base-images.yml` on tags only. It lint/builds/tests,
then publishes `${AICAGE_IMAGE_BASE_REPOSITORY}:<alias>-<version>` and `:latest` tags.

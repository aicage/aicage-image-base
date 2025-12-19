# aicage-image-base

Base layers for the aicage agent images. Each base bundles an OS and common prerequisites; agent
images in [aicage/aicage-image](https://github.com/aicage/aicage-image) build on top of these tags.

## What’s included

- Base aliases such as `ubuntu`, `fedora`, and `act`, each defined under `bases/<alias>/`.
- Multi-arch support: `linux/amd64` and `linux/arm64`.

## Tag format

`${AICAGE_BASE_REPOSITORY:-aicage/aicage-image-base}:<base>-<version>`

- Example: `aicage/aicage-image-base:ubuntu-latest`
- `<base>-latest` tags are convenience aliases for the newest published version of a base.

## Contributing

See `DEVELOPMENT.md` for how to build, test, and publish new base images. AI coding agents should
also read `AGENTS.md`.

# AI Agent Guide

Audience: AI coding agents working in `aicage-image-base`. Keep user-facing content in `README.md`;
use `DEVELOPMENT.md` for full build/test instructions.

## How to work

- Read `DEVELOPMENT.md` before editing scripts or Dockerfiles; it contains required commands and env
  vars.
- Use `rg` for searches; avoid reverting user changes or using destructive commands.
- Follow style conventions: Bash scripts with `#!/usr/bin/env bash`, `set -euo pipefail`, and
  two-space indents; Dockerfiles declare args at the top; Markdown line limit is 120 chars.

## Testing

- Run `scripts/test-all.sh` after changing base definitions, installers, or Docker build steps.
- If tests cannot be executed, note why and which platforms/bases are affected.

## Adding or updating bases

- Steps live in `DEVELOPMENT.md` (`bases/<alias>/base.yml` plus any installer tweaks).
- Ensure smoke coverage exists for new or changed bases in `tests/smoke/`.

## Notes

- Keep comments brief and only where behavior is non-obvious.
- Document any commands run that influence results (builds, tests).

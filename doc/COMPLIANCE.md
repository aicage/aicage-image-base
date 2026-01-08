# Compliance report (one-time)

## Summary

- Scope: aicage-image-base build scripts and Dockerfile in this repo.
- Base images: ubuntu, debian, fedora, alpine, alpine-minimal, node (node:lts-slim), act.
- Package managers: apt (Debian/Ubuntu), dnf (Fedora), apk (Alpine).
- No build steps delete `/usr/share/doc` or `/usr/share/licenses`.

## Package-manager installs (OK by default)

Packages are installed via apt/dnf/apk in `scripts/os-installers/distro/*/install/*.sh`.
No cleanup removes license directories; only package cache is removed for apt/dnf.

## Non-distro installs (manual review)

These are installed outside the base OS package managers and need license notice handling.

- Node.js. Install: tarball from nodejs.org. Source: (https://nodejs.org/dist/). License: MIT.
  Notices: stays in the extracted tree under `/usr/local` (no relocation). Script:
  `scripts/os-installers/generic/install_node.sh`.
- Rust (rustup). Install: `curl | sh`. Source: (https://sh.rustup.rs). License: Apache-2.0 OR MIT.
  Notices: copies `LICENSE-APACHE` + `LICENSE-MIT` to `/usr/share/licenses/rustup/`. Script:
  `scripts/os-installers/generic/install_rust.sh`.
- Eclipse Temurin JDK. Install: tarball from Adoptium API. Source: (https://api.adoptium.net).
  License: GPL-2.0 with Classpath Exception (OpenJDK). Notices: stays in the extracted tree under
  `/opt/java` (no relocation). Script: `scripts/os-installers/generic/install_jdk.sh`.
- Gradle. Install: zip from services.gradle.org. Source: (https://services.gradle.org). License:
  Apache-2.0. Notices: stays in the extracted tree under `/opt/gradle` (no relocation). Script:
  `scripts/os-installers/generic/install_gradle.sh`.
- uv (pipx). Install: pipx install. Source: (https://github.com/astral-sh/uv). License:
  Apache-2.0 OR MIT. Notices: stays in the pipx venv tree (no relocation). Script:
  `scripts/os-installers/generic/install_python.sh`.
- gosu (Fedora only). Install: GitHub release binary. Source: (https://github.com/tianon/gosu).
  License: Apache-2.0. Notices: stays with the downloaded release (no relocation). Script:
  `scripts/os-installers/distro/redhat/install/02-gosu.sh`.

## Notes and compliance posture

- Distro packages: license texts should remain available under distro-managed locations because we do
  not remove `/usr/share/doc` or `/usr/share/licenses`.
- Non-distro installs: some license texts live in their install roots; rustup is copied into
  `/usr/share/licenses/<agent>`.
- No high-attention licenses (AGPL/SSPL/Elastic/commercial EULA) were found in the non-distro list
  above; JDK is GPL-2.0 with Classpath Exception.

## What was checked (one-time)

- Searched installer scripts and Dockerfile for package-manager installs and non-distro installers.
- Searched for removal of `/usr/share/doc` and `/usr/share/licenses` and found none.

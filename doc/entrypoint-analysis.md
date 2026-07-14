# Entrypoint Analysis

This document analyzes [`scripts/entrypoint.sh`](../scripts/entrypoint.sh) as it
exists now.

Scope:

- Ignore the current Python caller.
- Treat the entrypoint as a standalone contract.
- Focus on what it reacts to, especially environment variables.
- Focus on current behavior only.
- Do not discuss future rootless Docker support here, except for the dedicated
  terminology and requirements section below.

## Executive Summary

The current script is not only a "switch to the right user" wrapper.

It combines these concerns:

1. Decide root vs non-root runtime behavior.
2. Create or reuse a runtime user inside the container.
3. Repair ownership for workspace and mounted-home parent paths.
4. Repair Docker socket group access for the runtime user.
5. Mirror mounted home content into `/root` when active `HOME` is `/root`.
6. Apply timezone settings.

So the complexity does not mainly come from the env var count. It comes from the
fact that the script mutates accounts, ownership, mount-facing paths, and system
configuration before it finally `exec`s the target command.

## Direct Inputs

### Environment variables read directly

| Variable                | Required? | Meaning in script                                   | Default in script |
|-------------------------|-----------|-----------------------------------------------------|-------------------|
| `AICAGE_WORKSPACE`      | No        | Working directory                                   | `/workspace`      |
| `AICAGE_ENTRYPOINT_CMD` | No        | Final command to execute                            | `bash`            |
| `AICAGE_UID`            | No        | Target runtime uid                                  | `0`               |
| `AICAGE_GID`            | No        | Target runtime gid                                  | `0`               |
| `AICAGE_HOST_USER`      | No        | Target runtime username                             | `root`            |
| `AICAGE_HOME`           | No        | Active home path                                    | `/root`           |
| `AICAGE_MOUNT_HOME`     | No        | Home mount anchor when different from active `HOME` | `AICAGE_HOME`     |
| `TZ`                    | No        | Requested timezone                                  | unset             |

### Other inputs the script reacts to

| Input                       | Why it matters                                                                |
|-----------------------------|-------------------------------------------------------------------------------|
| `$@`                        | Passed to the final command.                                                  |
| `/etc/skel`                 | Copied into home when safe.                                                   |
| `/proc/self/mountinfo`      | Used to discover mountpoints under `AICAGE_MOUNT_HOME` or `AICAGE_HOME`.      |
| Existing passwd/group state | Can trigger user deletion, user creation, and group creation.                 |
| `/var/run/docker.sock`      | Triggers Docker socket group repair.                                          |
| Existing filesystem layout  | Drives mountpoint checks, `chown`, directory creation, and symlink mirroring. |

## Effective Modes

The current script has two effective modes.

### Mode 1: Non-root runtime user mode

Trigger:

- `AICAGE_UID != 0` or `AICAGE_GID != 0`

Behavior:

- create or recreate the runtime user
- create or reuse the runtime primary group
- copy `/etc/skel` into `AICAGE_HOME` when safe
- repair Docker socket group access
- `chown` the workspace if it already exists and is not a mountpoint
- `chown` non-mounted parent directories under the home mount anchor
- set `HOME=AICAGE_HOME`
- `gosu` to `AICAGE_UID`

### Mode 2: Root runtime mode

Trigger:

- `AICAGE_UID == 0` and `AICAGE_GID == 0`

Behavior:

- do not create a runtime user
- do not repair Docker socket group access through `usermod`
- do not run workspace or home-parent ownership repair
- set `HOME=AICAGE_HOME`
- if `AICAGE_HOME=/root` but mounted home paths live somewhere else, mirror those
  mountpoints into `/root`
- execute the final command directly as root

## High-Level Flow

The main control flow is:

1. Derive `AICAGE_WORKSPACE`.
2. Derive `AICAGE_UID`, `AICAGE_GID`, `AICAGE_HOST_USER`, `AICAGE_HOME`.
3. Derive the mount anchor as `AICAGE_MOUNT_HOME` or `AICAGE_HOME`.
4. Refuse unsafe mount situations for `/home` and `/root`.
5. If in non-root mode:
   - create or recreate user/group
   - repair Docker socket group access
   - repair workspace and home-parent ownership
6. Refuse unsafe mount situations for `AICAGE_HOME` and maybe `AICAGE_MOUNT_HOME`.
7. Mirror mounted home content into `/root` when in root mode with a separate
   mount anchor.
8. Apply timezone.
9. Export `HOME`, `USER`, and adjusted `PATH`.
10. Ensure the workspace exists and `cd` into it.
11. `exec` either directly as root or via `gosu`.

## Behavior Matrix

| Behavior                                    | Non-root runtime user | Root runtime |
|---------------------------------------------|-----------------------|--------------|
| Create dynamic user/group                   | Yes                   | No           |
| Add runtime user to Docker socket group     | Yes                   | No           |
| Copy `/etc/skel` into `AICAGE_HOME`         | Yes                   | No           |
| `chown` existing workspace                  | Yes                   | No           |
| `chown` non-mounted home parent directories | Yes                   | No           |
| Mirror mountpoints into `/root`             | No                    | Sometimes    |
| Active `HOME` becomes `AICAGE_HOME`         | Yes                   | Yes          |
| Run final command through `gosu`            | Yes                   | No           |
| Apply `TZ`                                  | Yes                   | Yes          |
| Refuse mounted `/home` or `/root` roots     | Yes                   | Yes          |

## What Each Env Var Actually Controls

### `AICAGE_UID` and `AICAGE_GID`

These are the main mode selectors.

They control:

- root vs non-root mode
- created runtime uid/gid in non-root mode
- ownership repair targets
- whether `gosu` is used

They also affect the root-mirroring helper, because that helper only runs when
uid and gid are both `0`.

### `AICAGE_HOST_USER`

In non-root mode it controls:

- target username
- user deletion/recreation behavior
- the username added to the Docker socket group
- `USER` exported into the child environment

In root mode it mainly matters as exported `USER`, and for the final
`if [[ "${AICAGE_HOST_USER}" == "root" ]]` branch.

Important nuance:

- the script uses uid/gid to decide whether to behave as root
- but it uses username to decide whether to `exec` directly or through `gosu`

That means callers should keep these values coherent. The intended root contract
is `AICAGE_UID=0`, `AICAGE_GID=0`, `AICAGE_HOST_USER=root`.

### `AICAGE_HOME`

This is the most overloaded path input.

It controls:

- the active `HOME`
- where the runtime user is created
- where `/etc/skel` may be copied
- a mount-safety check target
- the base path used by root-mode mount mirroring

So `AICAGE_HOME` is not just cosmetic shell state. It is part of the script's
filesystem model.

### `AICAGE_MOUNT_HOME`

This is the second important path input.

It controls:

- which mountpoints count as "home-related mounts"
- which directories may be `chown`ed in non-root mode
- which mountpoints may be mirrored into `/root` in root mode
- the second mount-safety check when it differs from `AICAGE_HOME`

This variable exists because the script sometimes needs two different concepts:

- active runtime `HOME`
- mount namespace anchor for host-home content

When those are the same, `AICAGE_MOUNT_HOME` adds no behavior. When they differ,
it changes a lot.

### `AICAGE_WORKSPACE`

It controls:

- where the script `cd`s
- which directory may be `mkdir -p`'d
- which directory may be `chown`ed in non-root mode

Important nuance:

- the script gives it an internal default of `/workspace`
- it does not explicitly export that default

So the script can operate on `/workspace` even if the child process does not see
`AICAGE_WORKSPACE` in its environment.

### `AICAGE_ENTRYPOINT_CMD`

This only selects the final executable.

It does not change earlier setup behavior.

### `TZ`

If set, it mutates:

- `/etc/localtime`
- `/etc/timezone`

If invalid, startup fails.

## Function-Level Behavior Map

<!-- pyml disable md013 -->
| Function                             | Trigger                              | What it does                                                               |
|--------------------------------------|--------------------------------------|----------------------------------------------------------------------------|
| `ensure_home_is_not_mounted`         | Always called for home roots         | Refuses startup if the path or a parent is a mountpoint.                   |
| `copy_skel_if_safe`                  | Non-root user setup                  | Copies `/etc/skel` into the target home when the home is not a mountpoint. |
| `apply_timezone`                     | `TZ` set                             | Replaces system timezone files.                                            |
| `list_home_mount_points`             | Called by home-mount helpers         | Lists mountpoints under the mount-home anchor.                             |
| `filter_nested_mount_points`         | Called by home-mount helpers         | Keeps only top-level mountpoints.                                          |
| `ensure_home_mount_parents_owned`    | Non-root mode                        | `chown`s non-mounted parent directories under the mount-home anchor.       |
| `mirror_windows_home_mounts_to_root` | Root mode with separate mount anchor | Symlinks `/root/...` to mounted home paths.                                |
| `setup_user_and_group`               | Non-root mode                        | Rebuilds the runtime account and home model.                               |
| `setup_docker_group`                 | Non-root mode and socket exists      | Aligns socket gid and adds the runtime user to that group.                 |
| `setup_workspace`                    | Non-root mode                        | Repairs workspace and home-parent ownership.                               |
<!-- pyml enable md013 -->

## Current Side Effects

### Account database mutations

In non-root mode the script may:

- delete an existing user with the target name
- delete an existing user that already owns the target uid
- create a group
- create a user
- add the user to a Docker-related group
- modify the `docker` group gid

### Filesystem ownership mutations

In non-root mode the script may:

- `chown` `AICAGE_WORKSPACE`
- `chown` the mount-home anchor when it is a directory and not a mountpoint
- `chown` non-mounted parent directories under mounted home paths
- `chown` copied `/etc/skel` content

### Filesystem layout mutations

In root mode the script may:

- create directories under `/root`
- move existing `/root/...` entries aside with timestamped backup names
- create symlinks from `/root/...` into mounted home paths

### System config mutations

In all modes the script may:

- replace timezone files

## Existing Complexity

The main complexity already present in the current script comes from these
design choices.

### 1. The script has both an identity model and a mount model

`AICAGE_UID`, `AICAGE_GID`, and `AICAGE_HOST_USER` describe runtime identity.

`AICAGE_HOME` and `AICAGE_MOUNT_HOME` describe path semantics and mount
semantics.

Those are related, but not identical, which is why a single `HOME`-like
variable is not enough for all current cases.

### 2. Root mode is not just "skip gosu"

Root mode also changes:

- whether ownership repair runs
- whether Docker socket group repair runs
- whether mount mirroring into `/root` may run

So uid `0` is not only an identity choice. It also selects a different set of
filesystem side effects.

### 3. `AICAGE_HOME` and `AICAGE_MOUNT_HOME` both carry real semantics

The script needs to know:

- where the process should live
- where the mounted host-home namespace lives

When those differ, the current behavior depends on both.

## What Rootless Docker Support Should Mean

Here "rootless" means Docker's rootless mode on Linux, where the container may
still see uid `0` internally, but that root user is mapped and constrained by a
rootless daemon.

The chosen strategy is to keep rootless support deliberately simple:

- run as container `root`
- keep `HOME=/root`
- do not try to match the host username
- do not try to remap root's `HOME` to the host home path

That means rootless should be treated much closer to the current root-runtime
compatibility model than to the non-root Linux host-user model.

### Why this is the chosen direction

Trying to make rootless feel like normal Linux host-user mode by remapping root
to the host home path sounds attractive, but it makes the contract brittle:

- config lookup and mutable temp/state paths get mixed together
- bind-mounted host home ownership becomes harder to reason about
- tool-specific behavior starts leaking into the entrypoint contract
- rootless stops being easy to explain

Since rootless is a side feature here, simplicity is worth more than a more
"natural" home illusion.

### Practical rootless contract

For rootless, the caller should aim to produce the same broad runtime shape as
the current root-runtime mode:

- `AICAGE_UID=0`
- `AICAGE_GID=0`
- `AICAGE_HOST_USER=root`
- `AICAGE_HOME=/root`

What should explicitly not happen in the entrypoint for rootless:

- no dynamic runtime user creation
- no host username matching
- no host-home remapping for root
- no tool-specific temp/state path hacks

### What this means for the current script

This choice is intentionally conservative.

It means rootless support should reuse as much of the current root-mode behavior
as possible:

- root execution path
- root home semantics
- no extra repair layer just for rootless

So rootless does not need a large new entrypoint mode with separate home logic.
It mainly needs correct caller-side decisions about when to use the existing
root-runtime contract.

### Remaining caveat

Rootless Docker still changes what container root can effectively do against
bind-mounted host paths.

So even with the simplified strategy, caller-side logic must still avoid
assuming that rootless behaves like rootful Linux host-user mode.

But that does not require making the entrypoint contract much larger.

### Practical implication for future cleanup

Before adding or re-adding rootless Docker support, it still helps to separate
current behavior into two buckets:

- behavior that is really required by the runtime contract
- behavior that only exists to repair an inconvenient starting state

For the chosen rootless strategy, the second bucket should stay as small as
possible.

## Suspicious or Surprising Behavior

### Root execution is keyed off username at the final `exec`

The script decides root vs non-root setup from uid/gid, but the final branch is:

```bash
if [[ "${AICAGE_HOST_USER}" == "root" ]]; then
  exec "${AICAGE_ENTRYPOINT_CMD}" "$@"
else
  exec gosu "${AICAGE_UID}" "${AICAGE_ENTRYPOINT_CMD}" "$@"
fi
```

So a caller can create inconsistent input such as:

- `AICAGE_UID=0`
- `AICAGE_GID=0`
- `AICAGE_HOST_USER=demo`

That combination does not match the intended contract.

### Fresh workspace creation happens after ownership repair

Order today:

1. `setup_workspace` may `chown` an existing workspace
2. later, if the workspace is missing, `mkdir -p "${AICAGE_WORKSPACE}"` runs as root
3. then the final command runs, maybe under `gosu`

So a freshly created non-mounted workspace can end up root-owned.

That is not mainly a mode problem, but it is part of the current behavior.

## Minimal Mental Model

If someone only remembers one summary, it should be this:

<!-- pyml disable md013 -->
| Mode                  | Inputs that matter most                                       | What the script does                                                              |
|-----------------------|---------------------------------------------------------------|-----------------------------------------------------------------------------------|
| Non-root runtime user | `AICAGE_UID`, `AICAGE_GID`, `AICAGE_HOST_USER`, `AICAGE_HOME` | Create a matching user, repair access, then run through `gosu`.                   |
| Root runtime          | `AICAGE_HOME` and maybe `AICAGE_MOUNT_HOME`                   | Stay root, use the chosen home, and maybe mirror mounted home paths into `/root`. |
<!-- pyml enable md013 -->

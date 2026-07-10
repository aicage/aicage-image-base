# Entrypoint Pre-Rootless Analysis

This document analyzes the current
[`scripts/entrypoint.sh`](../scripts/entrypoint.sh) before any rootless Docker
logic is added.

Scope:

- Ignore the Python caller.
- Treat the entrypoint as a standalone contract.
- Focus on what it reacts to, especially environment variables.
- Identify complexity that already exists before rootless support.
- Identify where rootless support would have to hook into the current design.

## Executive Summary

The current script already has non-trivial complexity before rootless support.

It combines these concerns:

1. Select Linux-host mode vs non-Linux compatibility mode.
2. Create or reuse a runtime user inside the container.
3. Repair ownership for home and workspace paths.
4. Repair Docker socket group access.
5. Mirror non-Linux home mounts into `/root`.
6. Apply timezone configuration.

So the current complexity is not mainly "extra rootless logic". The script
already has multiple responsibilities and multiple filesystem side effects.

The key point for future simplification is this:

- the current script is not just an "identity mapper"
- it is also a mount-repair and compatibility layer

That matters because rootless support would not only change uid/gid behavior. It
would also interact with home selection, mount repair, and Docker socket
handling.

## Current Direct Inputs

### Environment variables read directly

| Variable | Required? | Current role |
| --- | --- | --- |
| `AICAGE_WORKSPACE` | No | Working directory and workspace ownership target. |
| `AICAGE_ENTRYPOINT_CMD` | No | Final command to execute. |
| `AICAGE_HOST_USER` | Linux-host mode only | Runtime username inside the container. |
| `AICAGE_UID` | Linux-host mode only | Runtime uid inside the container. |
| `AICAGE_GID` | Linux-host mode only | Runtime gid inside the container. |
| `AICAGE_HOME` | No | Desired home path and mount namespace anchor. |
| `AICAGE_HOST_IS_LINUX` | No | Mode selector: Linux host vs non-Linux host. |
| `TZ` | No | Timezone override. |

### Other inputs it reacts to

| Input | Why it matters |
| --- | --- |
| `$@` | Passed to the final command. |
| `/etc/skel` | Copied into home when safe. |
| `/proc/self/mountinfo` | Used to discover mounts under `AICAGE_HOME`. |
| Existing passwd/group state | Can trigger user and group deletion or creation. |
| `/var/run/docker.sock` | Triggers Docker socket group repair. |
| Existing filesystem layout | Drives mount safety checks, symlink creation, and `chown`. |

## Current Mode Model

Before rootless support, the script has two effective modes.

### Mode 1: Linux host mode

Trigger:

- `AICAGE_HOST_IS_LINUX` is set

Behavior:

- `TARGET_USER` becomes `AICAGE_HOST_USER` or `aicage`
- `AICAGE_UID` and `AICAGE_GID` default to `1000`
- a non-root user is created or recreated
- `HOME` becomes `AICAGE_HOME`
- `gosu` is used to run the final command as the target uid
- Docker socket group repair may run
- workspace and home-parent ownership repair may run

### Mode 2: Non-Linux compatibility mode

Trigger:

- `AICAGE_HOST_IS_LINUX` is unset

Behavior:

- `TARGET_USER` becomes `root`
- `AICAGE_UID` and `AICAGE_GID` are forced to `0`
- no dynamic user is created
- active `HOME` becomes `/root`
- mounts under `AICAGE_HOME` may be mirrored into `/root`
- final command runs directly as root

## Current High-Level Decision Flow

The main control flow today is:

1. Derive `AICAGE_WORKSPACE`.
2. Decide Linux-host mode vs non-Linux compatibility mode.
3. Derive `AICAGE_HOME`.
4. Refuse unsafe `/home` and `/root` mount situations.
5. In Linux-host mode:
   - create or recreate user/group
   - repair Docker socket group
   - repair workspace and home-parent ownership
6. In non-Linux compatibility mode:
   - keep root execution
7. Refuse unsafe final `AICAGE_HOME` mount situations.
8. Mirror non-Linux home mounts into `/root`.
9. Apply timezone.
10. Export `HOME`, `USER`, and `PATH`.
11. Ensure workspace exists and `cd` into it.
12. `exec` either directly as root or via `gosu`.

## What Each Env Var Actually Controls

### `AICAGE_HOST_IS_LINUX`

This is the primary mode flag today.

It does much more than signal host OS:

- selects root vs non-root execution model
- selects whether user/group creation runs
- selects whether Docker socket group repair runs
- selects whether home mounts are mirrored into `/root`
- indirectly changes what `HOME` becomes

This is not a minor hint. It is the top-level behavior selector.

### `AICAGE_HOME`

This is the most overloaded input in the current script.

It affects:

- default home selection
- what counts as a home-related mount
- what mount paths are considered unsafe
- where `/etc/skel` may be copied
- which directories may be `chown`ed
- what gets mirrored into `/root` in non-Linux compatibility mode
- what `HOME` becomes in Linux-host mode

So `AICAGE_HOME` is not only a desired home path. It is also the anchor for the
mount-repair logic.

### `AICAGE_UID` and `AICAGE_GID`

In Linux-host mode they control:

- created user identity
- created group identity
- ownership repair for home and workspace
- effective runtime identity under `gosu`

In non-Linux compatibility mode they are ignored because the script overwrites
them to `0:0`.

### `AICAGE_HOST_USER`

In Linux-host mode it controls:

- target username
- default home path when `AICAGE_HOME` is unset
- account creation and replacement behavior

In non-Linux compatibility mode it is irrelevant to runtime identity.

### `AICAGE_WORKSPACE`

It controls:

- which directory is `cd`'d into
- which directory may be `chown`ed in Linux-host mode
- which directory is created if missing

Important nuance:

- the script sets a default internally
- it does not export that default back into the child environment

So the script can operate on `/workspace` even when the child process sees no
`AICAGE_WORKSPACE` variable.

### `AICAGE_ENTRYPOINT_CMD`

This only chooses the final executable.

It does not affect earlier setup behavior.

### `TZ`

This is separate from identity behavior.

If set, it mutates:

- `/etc/localtime`
- `/etc/timezone`

If invalid, startup fails.

## Current Side Effects

The script mutates more than one might first expect.

### Account database mutations

In Linux-host mode it may:

- delete an existing user with the target name
- delete an existing user that already owns the target uid
- create a group
- create a user
- add the user to a Docker-related group
- modify the `docker` group gid

### Filesystem ownership mutations

In Linux-host mode it may:

- `chown` `AICAGE_HOME`
- `chown` non-mounted parent directories under `AICAGE_HOME`
- `chown` `AICAGE_WORKSPACE`
- `chown` files copied from `/etc/skel`

### Filesystem layout mutations

In non-Linux compatibility mode it may:

- create directories under `/root`
- replace existing `/root/...` entries with timestamped backups
- create symlinks from `/root/...` into mountpoints under `AICAGE_HOME`

### System config mutations

It may:

- replace timezone files

## Existing Complexity Before Rootless

The current complexity comes from these existing design choices.

### 1. Two different home models already exist

Today the script already has two home semantics:

- Linux-host mode: active `HOME` is `AICAGE_HOME`
- non-Linux compatibility mode: active `HOME` is `/root`, while `AICAGE_HOME`
  still defines a separate mount namespace

So even before rootless there is already a split between:

- "where the user actually lives"
- "where host-related home mounts conceptually live"

### 2. User identity and mount repair are coupled

The script does not just create a user and stop.

It assumes that once a uid/gid is chosen, ownership repairs must also happen for
workspace and for home-related mount parents.

That coupling is a major source of complexity.

### 3. Docker socket support is built into the identity path

`setup_docker_group()` is not an optional add-on. It is embedded into the Linux
host-user path.

That means the script assumes:

- Linux host mode implies a non-root runtime user
- if Docker socket exists, that user may need group surgery to access it

### 4. Non-Linux compatibility is not just "run as root"

The non-Linux path also mirrors selected mounts into `/root`.

So it is already a distinct compatibility mode with its own behavior, not just a
special case.

## Current Behavior Matrix

| Behavior | Linux host mode | Non-Linux compatibility mode |
| --- | --- | --- |
| Dynamic user creation | Yes | No |
| Runtime execution as root | No | Yes |
| `gosu` final exec | Yes | No |
| Active `HOME` is `AICAGE_HOME` | Yes | No |
| Active `HOME` is `/root` | No | Yes |
| Mirror home mounts into `/root` | No | Yes |
| Docker socket group repair | Yes | No |
| Home-parent ownership repair | Yes | No |
| Workspace ownership repair | Yes | No |
| Timezone application | Yes | Yes |

## Suspicious or Surprising Current Behavior

These are worth calling out independently from any rootless discussion.

### `AICAGE_WORKSPACE` default is internal only

The script defaults `AICAGE_WORKSPACE` to `/workspace`, but the child process
does not inherit that default unless it was present in the original environment.

This creates a split between:

- entrypoint internal behavior
- child-process visible environment

### Fresh workspace creation happens after ownership repair

In Linux-host mode:

1. `setup_workspace` may `chown` an existing workspace
2. later the script may `mkdir -p "${AICAGE_WORKSPACE}"` as root
3. then it drops privileges with `gosu`

So a newly created non-mounted workspace may be root-owned.

That is an existing pre-rootless asymmetry.

### `AICAGE_HOME` carries two meanings

It is both:

- desired user home path
- mount namespace anchor for repair and mirroring logic

That makes the variable powerful, but also conceptually heavy.

## What Rootless Would Need to Change

Without proposing a final design, rootless support would need to answer these
questions against the current pre-rootless contract.

### 1. Should rootless behave more like Linux-host mode or more like non-Linux mode?

Linux-host mode today means:

- non-root execution
- dynamic user creation
- ownership repair
- `HOME=AICAGE_HOME`

Non-Linux compatibility mode today means:

- root execution
- no dynamic user creation
- no ownership repair
- active `HOME=/root`

Rootless Docker likely wants a mixed shape:

- root execution
- no dynamic user creation
- but probably still `HOME=AICAGE_HOME`

That mixed shape does not currently exist.

### 2. Should Docker socket group repair still run?

Today that logic only exists in the Linux host-user path.

For rootless Docker, the answer may be "no", but the current script structure
does not isolate that concern cleanly from the rest of Linux-host mode.

### 3. Should workspace and home-parent ownership repair still run?

Today those repairs are tightly tied to Linux host-user mode.

If rootless does not need them, then rootless cannot simply reuse that mode.

### 4. What should active `HOME` be?

This is one of the most important questions.

The current script only supports:

- non-root with `HOME=AICAGE_HOME`
- root with `HOME=/root`

If rootless wants:

- root with `HOME=AICAGE_HOME`

then that is a third home model.

That is exactly why rootless added on top of the current script can quickly make
the script harder to reason about.

## Simplification Opportunities Before Any Rootless Work

These are the areas where cleanup likely helps before adding any new mode.

### Opportunity 1: Separate mode selection from side effects

The script would be easier to reason about if it first computed a clear runtime
mode and only then ran mode-specific actions.

Today the mode decision leaks into multiple later functions.

### Opportunity 2: Separate home semantics from mount-repair semantics

Right now `AICAGE_HOME` does too much.

If home selection and mount namespace selection were conceptually separate, the
 script would likely be easier to extend.

### Opportunity 3: Separate identity setup from Docker socket support

`setup_docker_group()` is currently coupled to Linux-host mode.

If Docker socket support were its own explicit concern, later mode additions
would be easier.

### Opportunity 4: Decide whether non-Linux compatibility is a first-class mode

Right now it clearly is.

If that remains true, it should probably be treated as an explicit mode in the
mental model and documentation, not just as the else-branch of Linux behavior.

## Recommendation

Before adding any rootless logic, the current script should be understood as
already having:

1. one Linux host-user mode
2. one non-Linux root compatibility mode
3. several side-effect subsystems layered onto those modes

The most useful pre-rootless cleanup would probably be:

1. document the current two-mode model explicitly
2. make side-effect subsystems easier to see as separate concerns
3. fix any current asymmetries such as workspace creation vs ownership repair

Then rootless can be judged against a cleaner baseline:

- is it a third explicit mode?
- or can it reuse one existing mode plus one or two small overrides?

My current assessment from the pre-rootless script alone is:

- the script already has enough ballast that rootless should not be added as a
  small ad hoc branch
- if rootless is added later, it should be done against an explicit mode model
  rather than by inferring behavior from scattered conditions

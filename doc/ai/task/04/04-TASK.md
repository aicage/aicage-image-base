# Task: Group matching GID of docker.sock

## Current situation

Docker is installed to docker images, see files at:
- scripts/os-installers/distro/*/install/40-docker.sh
- scripts/os-installers/helpers/install_*_alpine.sh

During this installation a `docker` group is created.

When running the images, the entrypoint at `scripts/entrypoint.sh` sets up a user matching the host user and puts the 
user in the `docker` group.

## Problem

The docker.sock mounted from host has another GID as the created `docker` group.

## Task

Create a group matching GID of docker.sock in entrypoint.sh. No longer create the group during image build.

Edge-cases:
- A group with GID of docker.sock might already exists.
  Then add the user to that existing group.
  - In some distros, the `docker` group might be created when installing docker.
    In that case, update the `GID` of the `docker` group to that of the docker.sock.
    Then add the user to `docker` group.

## Side-task: Cleanup install scripts in `scripts/os-installers/helpers`

Merge the 2 `scripts/os-installers/helpers/install_docker_*.sh` scripts into the 
`scripts/os-installers/distro/*/install/40-docker.sh` which call them.

Also move `scripts/os-installers/helpers/install_node_alpine.sh` to `scripts/os-installers/generic` and update
`scripts/os-installers/distro/alpine-minimal/install/25-node.sh` which call them.

`scripts/os-installers/helpers` is then empty and can be removed.

## Testing

The current tests for docker did not catch the above problem. Add tests for this, at least one test must:
- simulate a host user passed to docker (use a dummy UID and the real GID of docker.sock on host)
- inside the container start a `hello-world` docker image
- validate the output to see if the hello-world ran

## Task Workflow

Don't forget to read AGENTS.md and always use the existing venv.

You shall follow this order:
1. Read documentation and code to understand the task. 
2. Aks me questions if something is not clear to you
3. Present me with an implementation solution - this needs my approval
4. Implement the change autonomously including a loop of running-tests, fixing bugs, running tests
5. Run linters as in the pipeline `.github/workflows/publish.yml`
6. Present me the change for review
7. Interactively react to my review feedback
8. 
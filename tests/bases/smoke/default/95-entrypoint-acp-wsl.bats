#!/usr/bin/env bats

@test "entrypoint translates ACP paths through acp-wsl" {
  run docker run --rm \
    --entrypoint /bin/bash \
    --env AICAGE_ACP_WSL=1 \
    --env AICAGE_ENTRYPOINT_CMD=/tmp/acp-agent \
    --env AICAGE_WORKSPACE=/workspace \
    --env AICAGE_UID=1234 \
    --env AICAGE_GID=2345 \
    --env AICAGE_HOST_USER=demo \
    --env AICAGE_HOME=/home/demo \
    "${AICAGE_IMAGE_BASE_IMAGE}" \
    -c '
      set -euo pipefail
      cat >/tmp/acp-agent <<'\''EOF'\''
#!/usr/bin/env bash
cat >/tmp/agent-input.json
EOF
      chmod 755 /tmp/acp-agent
      printf "%s\\n" '\''{"jsonrpc":"2.0","id":1,"method":"session/new","params":{"cwd":"C:\\work\\project"}}'\'' |
        /usr/local/bin/entrypoint.sh
      grep -Fq '\''/mnt/c/work/project'\'' /tmp/agent-input.json
      cat /tmp/agent-input.json
    '
  [ "$status" -eq 0 ]
  [[ "${output}" == *'"/mnt/c/work/project"'* ]]
}

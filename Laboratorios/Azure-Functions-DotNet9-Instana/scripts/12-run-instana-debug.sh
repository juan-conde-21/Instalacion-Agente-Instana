#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
name="${1:-instana-dotnet9-debug}"
DUMPS="$LAB_ROOT/evidencias/phase12/dumps"
mkdir -p "$DUMPS"
chmod 0777 "$DUMPS"
docker run -d --name "$name" --cap-add SYS_PTRACE --security-opt seccomp=unconfined --add-host host.docker.internal:host-gateway -e INSTANA_AGENT_HOST=host.docker.internal -e INSTANA_AGENT_PORT=42699 -v "$DUMPS:/dumps" -p 127.0.0.1:0:80 --entrypoint /usr/bin/strace instana-dotnet9-lab:instana-debug -ff -ttt -s 256 -e trace=process,signal -o /dumps/strace /bin/bash /opt/startup/start_nonappservice.sh

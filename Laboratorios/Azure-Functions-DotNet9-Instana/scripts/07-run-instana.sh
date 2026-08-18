#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
OUT="$LAB_ROOT/evidencias/phase04"
mkdir -p "$OUT"
name=instana-dotnet9-manual
docker run -d --name "$name" --add-host host.docker.internal:host-gateway -e INSTANA_AGENT_HOST=host.docker.internal -e INSTANA_AGENT_PORT=42699 -p 127.0.0.1:0:80 instana-dotnet9-lab:instana >"$OUT/container-id.txt"
port="$(docker port "$name" 80/tcp | sed 's/.*://g')"
for attempt in $(seq 1 30); do curl --fail --silent --show-error "http://127.0.0.1:$port/api/health" >"$OUT/health.json" && break; sleep 1; done
sleep 3
docker logs --timestamps "$name" >"$OUT/startup.log" 2>&1 || true
docker inspect "$name" >"$OUT/container-inspect.json"
docker top "$name" -eo pid,ppid,user,comm,args >"$OUT/processes.txt" 2>&1 || true
docker exec "$name" sh -c 'for p in /proc/[0-9]*; do echo PID=${p##*/}; tr "\0" "\n" < "$p/environ" 2>/dev/null | grep -Ei "INSTANA|CORECLR|DOTNET_STARTUP_HOOKS|PROFILER" || true; done' >"$OUT/process-environments.txt" 2>&1 || true
docker exec "$name" sh -c 'for p in /proc/[0-9]*; do echo PID=${p##*/}; grep -E "CoreProfiler|Instana" "$p/maps" 2>/dev/null || true; done' >"$OUT/process-maps-instana.txt" 2>&1 || true
echo "$OUT"



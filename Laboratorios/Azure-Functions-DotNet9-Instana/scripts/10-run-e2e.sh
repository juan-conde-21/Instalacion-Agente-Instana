#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
name="${1:-instana-dotnet9-e2e}"
OUT="$LAB_ROOT/evidencias/phase07"
mkdir -p "$OUT"
if docker inspect "$name" >/dev/null 2>&1; then echo "El contenedor $name ya existe" >&2; exit 2; fi
docker run -d --name "$name" --add-host host.docker.internal:host-gateway -e INSTANA_AGENT_HOST=host.docker.internal -e INSTANA_AGENT_PORT=42699 -e INSTANA_SERVICE_NAME=instana-dotnet9-functions-lab -p 127.0.0.1:0:80 instana-dotnet9-lab:instana >"$OUT/container-id.txt"
port="$(docker port "$name" 80/tcp | sed 's/.*://')"
code=000
for attempt in $(seq 1 30); do
  code="$(curl --silent --output "$OUT/health.json" --write-out '%{http_code}' --max-time 5 "http://127.0.0.1:$port/api/health" || true)"
  [ "$code" = 200 ] && break
  sleep 1
done
[ "$code" = 200 ] || { docker inspect "$name" >"$OUT/container-inspect-failed.json"; docker logs "$name" >"$OUT/startup-failed.log" 2>&1; echo "health no disponible" >&2; exit 1; }
docker inspect "$name" >"$OUT/container-inspect.json"
docker top "$name" -eo pid,ppid,user,comm,args >"$OUT/processes.txt"
docker exec "$name" sh -c 'for p in /proc/[0-9]*; do echo PID=${p##*/}; grep -E "CoreProfiler|Instana" "$p/maps" 2>/dev/null || true; done' >"$OUT/process-maps-instana.txt"
docker exec "$name" timeout 5 bash -c 'exec 3<>/dev/tcp/host.docker.internal/42699; printf "GET /status HTTP/1.1\r\nHost: host.docker.internal\r\nConnection: close\r\n\r\n" >&3; head -n 5 <&3' >"$OUT/agent-connectivity.txt"
docker logs --timestamps "$name" >"$OUT/startup.log" 2>&1
printf 'container=%s\nport=%s\nhealth_code=%s\nagent_host=host.docker.internal\nagent_port=42699\nservice_name=instana-dotnet9-functions-lab\n' "$name" "$port" "$code" >"$OUT/configuration-nonsecret.txt"
cat "$OUT/configuration-nonsecret.txt"

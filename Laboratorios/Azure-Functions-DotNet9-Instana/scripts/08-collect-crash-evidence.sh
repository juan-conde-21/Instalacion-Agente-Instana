#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
name="${1:?uso: $0 CONTENEDOR}"
OUT="$LAB_ROOT/evidencias/crash-$name-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$OUT"
docker inspect "$name" >"$OUT/container-inspect.json" 2>&1 || true
docker logs --timestamps "$name" >"$OUT/container.log" 2>&1 || true
docker top "$name" -eo pid,ppid,user,comm,args >"$OUT/processes.txt" 2>&1 || true
docker events --since 30m --until "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --filter "container=$name" >"$OUT/docker-events.txt" 2>&1 || true
echo "$OUT"

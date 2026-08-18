#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
OUT="$LAB_ROOT/evidencias/phase02"
mkdir -p "$OUT"
: >"$OUT/baseline-runs.tsv"
for run in 1 2 3; do
  name="instana-dotnet9-clean-$run"
  docker run -d --name "$name" -p 127.0.0.1:0:80 instana-dotnet9-lab:clean >"$OUT/run-$run-container-id.txt"
  port="$(docker port "$name" 80/tcp | sed 's/.*://')"
  ready=0
  for attempt in $(seq 1 30); do
    if curl --fail --silent --show-error "http://127.0.0.1:$port/api/health" >"$OUT/run-$run-health.json"; then ready=1; break; fi
    sleep 1
  done
  docker logs --timestamps "$name" >"$OUT/run-$run.log" 2>&1 || true
  docker stats --no-stream "$name" >"$OUT/run-$run-stats.txt" 2>&1 || true
  docker top "$name" -eo pid,ppid,user,comm,args >"$OUT/run-$run-processes.txt" 2>&1 || true
  docker inspect "$name" >"$OUT/run-$run-inspect-running.json"
  running="$(docker inspect -f '{{.State.Running}}' "$name")"
  printf '%s\tready=%s\trunning=%s\tport=%s\n' "$run" "$ready" "$running" "$port" >>"$OUT/baseline-runs.tsv"
  docker restart "$name" >"$OUT/run-$run-restart.txt"
  sleep 3
  docker inspect "$name" >"$OUT/run-$run-inspect-restarted.json"
  docker stop "$name" >"$OUT/run-$run-stop.txt"
  docker inspect "$name" >"$OUT/run-$run-inspect-stopped.json"
done


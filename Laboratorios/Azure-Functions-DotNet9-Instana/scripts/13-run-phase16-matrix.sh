#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
out=evidencias/phase16
printf 'variant\tfunction_count\tmode\tidle_seconds\tstable\thealth_after_idle\tworker_initialized\trestart_limit\tdocker_exit\toom\thost_result\n' > "$out/matrix.tsv"
variants=(a0 a1 a2 b)
for mode in clean instana; do
  for idx in "${!variants[@]}"; do
    v="${variants[$idx]}"
    name="phase16-${v}-${mode}-run"
    offset=0; [[ "$mode" == instana ]] && offset=10; port=$((18301 + idx + offset))
    args=(docker run -d --name "$name" -p "${port}:80")
    if [[ "$mode" == instana ]]; then
      args+=(--add-host=host.docker.internal:host-gateway -e INSTANA_AGENT_HOST=host.docker.internal -e INSTANA_AGENT_PORT=42699 -e DOTNET_DbgEnableMiniDump=0)
    fi
    "${args[@]}" "instana-dotnet9-lab:phase16-${v}-${mode}" >/dev/null
    sleep 30
    running=$(docker inspect "$name" --format '{{.State.Running}}')
    health=NOT_TESTED
    if [[ "$running" == true ]]; then
      health=$(curl -sS -o /dev/null -w '%{http_code}' "http://127.0.0.1:${port}/api/health" 2>/dev/null || true)
      sleep 2
    fi
    docker logs --timestamps "$name" > "$out/logs/${v}-${mode}.log" 2>&1 || true
    worker=$(grep -c 'Worker process started and initialized' "$out/logs/${v}-${mode}.log" || true)
    limit=$(grep -c 'Exceeded language worker restart retry count' "$out/logs/${v}-${mode}.log" || true)
    state=$(docker inspect "$name" --format '{{.State.Running}}|{{.State.ExitCode}}|{{.State.OOMKilled}}')
    IFS='|' read -r final_running exitcode oom <<< "$state"
    stable=NO; host=RECYCLED
    if [[ "$final_running" == true ]]; then stable=YES; host=RUNNING; fi
    count=1; [[ "$v" == b ]] && count=2
    printf '%s\t%s\t%s\t30\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "${v^^}" "$count" "$mode" "$stable" "$health" "$worker" "$limit" "$exitcode" "$oom" "$host" | tee -a "$out/matrix.tsv"
    if [[ "$final_running" == true ]]; then docker stop -t 15 "$name" >/dev/null || true; fi
    docker container rm "$name" >/dev/null
  done
done

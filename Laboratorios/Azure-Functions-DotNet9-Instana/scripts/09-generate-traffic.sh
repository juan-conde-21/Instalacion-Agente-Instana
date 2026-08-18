#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
name="${1:-instana-dotnet9-e2e}"
iterations="${2:-30}"
OUT="$LAB_ROOT/evidencias/phase08"
mkdir -p "$OUT"
port="$(docker port "$name" 80/tcp | sed 's/.*://')"
tsv="$OUT/traffic.tsv"
summary="$OUT/traffic-summary.txt"
printf 'timestamp\tendpoint\thttp_code\ttime_total\n' >"$tsv"
for iteration in $(seq 1 "$iterations"); do
  for endpoint in health test error; do
    timestamp="$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
    if ! result="$(curl --silent --output "$OUT/last-$endpoint-body.txt" --write-out '%{http_code}\t%{time_total}' --max-time 10 "http://127.0.0.1:$port/api/$endpoint")"; then result=$'000\t10.000000'; fi
    printf '%s\t%s\t%s\n' "$timestamp" "$endpoint" "$result" >>"$tsv"
  done
  sleep 1
done
awk -F '\t' 'NR>1 {total++; if ($3 ~ /^2/) ok++; else if ($3 ~ /^5/) server++; else other++; latency+=$4} END {printf "requests=%d\nhttp_2xx=%d\nhttp_5xx=%d\nother=%d\navg_latency_seconds=%.6f\n", total, ok, server, other, latency/total}' "$tsv" >"$summary"
printf 'started=%s\nfinished=%s\n' "$(sed -n '2s/\t.*//p' "$tsv")" "$(tail -1 "$tsv" | cut -f1)" >>"$summary"
cat "$summary"

#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
name="${1:?uso: $0 CONTAINER [SECONDS]}"
duration="${2:-45}"
OUT="$LAB_ROOT/evidencias/phase13"
mkdir -p "$OUT"
out="$OUT/${3:-worker-lifecycle.tsv}"
printf 'timestamp\tpid\tppid\tstate\tcommand\tevent\n' >"$out"
declare -A seen=()
end=$((SECONDS + duration))
while (( SECONDS < end )); do
  current=()
  while read -r pid ppid state command; do
    [[ -n "${pid:-}" ]] || continue
    current+=("$pid")
    if [[ -z "${seen[$pid]+x}" ]]; then
      seen[$pid]=active
      printf '%s\t%s\t%s\t%s\t%s\tSTART\n' "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)" "$pid" "$ppid" "$state" "$command" >>"$out"
    fi
  done < <(docker top "$name" -eo pid,ppid,state,args 2>/dev/null | tail -n +2 | awk '/dotnet \/home\/site\/wwwroot\/InstanaCrashLab.dll/ {pid=$1; ppid=$2; state=$3; $1=$2=$3=""; sub(/^ +/, ""); print pid, ppid, state, $0}')
  for pid in "${!seen[@]}"; do
    [[ "${seen[$pid]}" = active ]] || continue
    found=false
    for active_pid in "${current[@]}"; do [[ "$active_pid" = "$pid" ]] && found=true; done
    if ! $found; then
      seen[$pid]=ended
      printf '%s\t%s\t-\t-\t-\tEND_OBSERVED\n' "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)" "$pid" >>"$out"
    fi
  done
  sleep 0.2
done
cat "$out"

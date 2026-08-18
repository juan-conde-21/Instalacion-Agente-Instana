#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
OUT="$LAB_ROOT/evidencias/phase04"
mkdir -p "$OUT"
cid="$(docker create --entrypoint /bin/sh instana-dotnet9-lab:instana)"
trap 'docker rm -f "$cid" >/dev/null 2>&1 || true' EXIT
docker cp "$cid:/home/site/wwwroot/instana_tracing/CoreProfiler.so" "$OUT/CoreProfiler.so"
file "$OUT/CoreProfiler.so" >"$OUT/profiler-file.txt"
docker run --rm --entrypoint /usr/bin/ldd instana-dotnet9-lab:instana /home/site/wwwroot/instana_tracing/CoreProfiler.so >"$OUT/profiler-ldd-container.txt" 2>&1 || true
readelf -d "$OUT/CoreProfiler.so" >"$OUT/profiler-readelf-dynamic.txt"
readelf --version-info "$OUT/CoreProfiler.so" >"$OUT/profiler-readelf-versions.txt"
strings "$OUT/CoreProfiler.so" | grep -Eo 'GLIBC(X|XX)?_[0-9]+(\.[0-9]+)*' | sort -Vu >"$OUT/profiler-required-symbol-versions.txt" || true
echo "$OUT"



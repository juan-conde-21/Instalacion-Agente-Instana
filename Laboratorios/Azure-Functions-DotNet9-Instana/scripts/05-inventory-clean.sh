#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
OUT="$LAB_ROOT/evidencias/phase03"
mkdir -p "$OUT"
docker run --rm --entrypoint /bin/sh instana-dotnet9-lab:clean -c 'env | grep -Ei "INSTANA|CORECLR|DOTNET|APPINSIGHTS|APPLICATIONINSIGHTS|OTEL|PROFILER" || true; find / -iname "*instana*" 2>/dev/null; find / -iname "*profiler*" 2>/dev/null' >"$OUT/container-instrumentation-inventory.txt" 2>&1
docker run --rm -v "$LAB_ROOT:/lab:ro" -w /lab mcr.microsoft.com/dotnet/sdk:9.0 dotnet list src/InstanaCrashLab/InstanaCrashLab.csproj package --include-transitive >"$OUT/nuget-packages.txt" 2>&1 || true


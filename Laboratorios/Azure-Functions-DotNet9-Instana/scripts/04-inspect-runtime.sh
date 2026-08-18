#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
OUT="$LAB_ROOT/evidencias/phase01"
mkdir -p "$OUT"
docker run --rm --entrypoint /bin/sh instana-dotnet9-lab:clean -c 'cat /etc/os-release; ldd --version; uname -m; dotnet --info; find /azure-functions-host -maxdepth 2 -type f -name "*.runtimeconfig.json" -print 2>/dev/null' >"$OUT/runtime-inventory.txt" 2>&1


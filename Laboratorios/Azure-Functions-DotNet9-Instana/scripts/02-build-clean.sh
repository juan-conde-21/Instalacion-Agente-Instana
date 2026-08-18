#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"
OUT="$LAB_ROOT/evidencias/phase02"
mkdir -p "$OUT"
docker build --progress=plain -f "$LAB_ROOT/docker/Dockerfile.clean" -t instana-dotnet9-lab:clean "$LAB_ROOT" >"$OUT/clean-build.log" 2>&1
docker image inspect instana-dotnet9-lab:clean >"$OUT/clean-image-inspect.json"


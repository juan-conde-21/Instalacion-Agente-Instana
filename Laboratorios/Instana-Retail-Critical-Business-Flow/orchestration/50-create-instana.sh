#!/usr/bin/env bash
set -euo pipefail

BASE="/opt/instana-demo"
API="${BASE}/instana-api"

echo
echo "========================================================"
echo " INSTANA RETAIL LAB - INSTANA AS CODE"
echo "========================================================"
echo

[[ -x "${API}/00-load-runtime-env.sh" ]] || {
    echo "[FAIL] Missing runtime environment loader"
    exit 1
}

[[ -x "${API}/17-rebuild-instana.sh" ]] || {
    echo "[FAIL] Missing Instana rebuild script"
    exit 1
}

source "${API}/00-load-runtime-env.sh"

"${API}/17-rebuild-instana.sh"

echo
echo "========================================================"
echo " INSTANA AS CODE = COMPLETE"
echo "========================================================"

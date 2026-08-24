#!/usr/bin/env bash
set -euo pipefail

BASE="/opt/instana-demo"
API="${BASE}/instana-api"

echo
echo "========================================================"
echo " INSTANA RETAIL LAB - GLOBAL PRECHECK"
echo "========================================================"
echo

[[ -x "${API}/13-precheck-all.sh" ]] || {
    echo "[FAIL] Missing ${API}/13-precheck-all.sh"
    exit 1
}

"${API}/13-precheck-all.sh"

echo
echo "========================================================"
echo " GLOBAL PRECHECK = PASS"
echo "========================================================"

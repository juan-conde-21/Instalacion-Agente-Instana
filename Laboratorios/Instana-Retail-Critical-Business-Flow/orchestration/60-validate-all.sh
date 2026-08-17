#!/usr/bin/env bash
set -euo pipefail

BASE="/opt/instana-demo"
ORCH="${BASE}/orchestration"
API="${BASE}/instana-api"

echo
echo "========================================================"
echo " INSTANA RETAIL LAB - END TO END VALIDATION"
echo "========================================================"
echo

echo
echo "----- BASTION -----"
"${ORCH}/20-setup-bastion.sh" --check

echo
echo "----- BLUEBOX -----"
"${ORCH}/30-setup-bluebox.sh" --check

echo
echo "----- DEMO APPS -----"
"${ORCH}/40-setup-demoapps.sh" --check

echo
echo "----- INSTANA / DEMO STATUS -----"

if [[ -x "${API}/06-demo-status.sh" ]]; then
    "${API}/06-demo-status.sh"
else
    echo "[WARN] 06-demo-status.sh not available"
fi

echo
echo "========================================================"
echo " END TO END VALIDATION = COMPLETE"
echo "========================================================"

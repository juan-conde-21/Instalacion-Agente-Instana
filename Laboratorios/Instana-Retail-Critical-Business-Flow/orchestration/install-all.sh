#!/usr/bin/env bash
set -euo pipefail

BASE="/opt/instana-demo/orchestration"

STEP() {
    echo
    echo "########################################################"
    echo " $1"
    echo "########################################################"
    echo
}

START="$(date +%s)"

STEP "00 - PRECHECK"
"${BASE}/00-precheck.sh"

STEP "20 - BASTION / SOURCE"
"${BASE}/20-setup-bastion.sh" --apply

STEP "30 - BLUEBOX / CENTRAL + FILE MONITORING + OTEL"
"${BASE}/30-setup-bluebox.sh" --apply

STEP "40 - DEMO APPS / RETAIL + OTEL"
"${BASE}/40-setup-demoapps.sh" --apply

STEP "50 - INSTANA AS CODE"
"${BASE}/50-create-instana.sh"

STEP "60 - END TO END VALIDATION"
"${BASE}/60-validate-all.sh"

END="$(date +%s)"
ELAPSED=$((END - START))

echo
echo "========================================================"
echo " INSTANA RETAIL LAB = INSTALLATION COMPLETE"
echo "========================================================"
echo
echo "Elapsed: ${ELAPSED}s"
echo

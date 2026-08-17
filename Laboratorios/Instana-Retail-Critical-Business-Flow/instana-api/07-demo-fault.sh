#!/usr/bin/env bash
set -uo pipefail

BASE_DIR="/opt/instana-demo/instana-api"
SOURCE_LOG="/opt/instana-demo/source/logs/source-job.log"

if ! type bluebox_sudo >/dev/null 2>&1; then
    source "${BASE_DIR}/00-load-lab-env.sh"
fi

echo
echo "======================================================"
echo " RETAIL CRITICAL BUSINESS FLOW - INJECT FAULT"
echo "======================================================"

echo
echo "=== [1/4] Estado previo ==="

PERMS_BEFORE=$(
  bluebox_exec \
    'stat -c "%a" /opt/instana-demo/central/published'
)

echo "Central published permissions : ${PERMS_BEFORE}"

if [[ "${PERMS_BEFORE}" != "755" ]]; then
    echo
    echo "ERROR: el laboratorio no está en baseline."
    echo "Esperado: PERMS=755"
    echo "Actual  : PERMS=${PERMS_BEFORE}"
    echo
    echo "Ejecute primero:"
    echo "  bluebox_sudo /opt/instana-demo/scripts/recover-stale.sh"
    exit 1
fi


echo
echo "=== [2/4] Bloqueando distribución ==="

bluebox_sudo \
  /opt/instana-demo/scripts/fault-stale.sh

PERMS_AFTER=$(
  bluebox_exec \
    'stat -c "%a" /opt/instana-demo/central/published'
)

echo
echo "Permissions after fault : ${PERMS_AFTER}"

if [[ "${PERMS_AFTER}" != "555" ]]; then
    echo "ERROR: la falla no quedó aplicada."
    exit 1
fi


echo
echo "=== [3/4] Forzando intento de SOURCE ==="

set +e
systemctl start instana-demo-source.service
SOURCE_RC=$?
set -e 2>/dev/null || true

if [[ "${SOURCE_RC}" -eq 0 ]]; then
    echo "SOURCE terminó sin error."
    echo "ADVERTENCIA: esperábamos fallo de distribución."
else
    echo "SOURCE falló como se esperaba."
    echo "systemctl rc=${SOURCE_RC}"
fi


echo
echo "=== [4/4] Evidencia del SOURCE ==="

tail -n 8 "${SOURCE_LOG}" 2>/dev/null || true

LAST_UPLOAD_STATUS=$(
  grep 'event=upload_' "${SOURCE_LOG}" 2>/dev/null \
    | tail -1 || true
)

echo
echo "Último resultado de distribución:"
echo "${LAST_UPLOAD_STATUS}"


if [[ "${LAST_UPLOAD_STATUS}" == *"event=upload_failed"* ]]; then

    echo
    echo "======================================================"
    echo " FAULT INJECTION = PASS"
    echo "======================================================"
    echo
    echo "Distribución        : BLOQUEADA"
    echo "Central permissions : 555"
    echo "SOURCE upload       : FAILED AS EXPECTED"
    echo
    echo "IMPORTANTE:"
    echo "Central y Retail siguen técnicamente disponibles."
    echo "El archivo se volverá STALE al superar 120 segundos."
    echo
    echo "Siguiente paso:"
    echo "  ./08-demo-observe.sh"

else

    echo
    echo "======================================================"
    echo " FAULT INJECTION = CHECK REQUIRED"
    echo "======================================================"
    exit 1

fi

echo

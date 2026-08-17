#!/usr/bin/env bash
set -uo pipefail

BASE_DIR="/opt/instana-demo/instana-api"

CENTRAL_URL="http://192.168.252.35:18082"
RETAIL_URL="http://192.168.252.33:18083"

BUSINESS_SKU="P00001"

MAX_WAIT=180
POLL_INTERVAL=10


# ============================================================
# LAB ENV
# ============================================================

if ! type bluebox_exec >/dev/null 2>&1; then

    if ! source "${BASE_DIR}/00-load-lab-env.sh" >/dev/null 2>&1; then
        echo "ERROR: no fue posible cargar acceso a Bluebox."
        exit 1
    fi

fi


echo
echo "======================================================"
echo " RETAIL CRITICAL BUSINESS FLOW - OBSERVE IMPACT"
echo "======================================================"


# ============================================================
# 1 - VERIFY FAULT
# ============================================================

echo
echo "=== [1/5] Verificando falla activa ==="

PERMS=$(
  bluebox_exec \
    'stat -c "%a" /opt/instana-demo/central/published' \
    2>/dev/null
)

echo "Central published permissions : ${PERMS}"

if [[ "${PERMS}" != "555" ]]; then

    echo
    echo "ERROR: la distribución no está bloqueada."
    echo "Esperado : 555"
    echo "Actual   : ${PERMS}"
    exit 1

fi


# ============================================================
# 2 - WAIT UNTIL STALE
# ============================================================

echo
echo "=== [2/5] Esperando condición STALE ==="

START_TIME=$(date +%s)

while true
do

    STATUS_JSON=$(
      curl -sS \
        "${RETAIL_URL}/api/status" \
        2>/dev/null || echo '{}'
    )

    STATUS=$(
      jq -r '.status // "UNKNOWN"' \
        <<<"${STATUS_JSON}" \
        2>/dev/null
    )

    AGE=$(
      jq -r '.ageSeconds // -1' \
        <<<"${STATUS_JSON}" \
        2>/dev/null
    )

    MAX_AGE=$(
      jq -r '.maxAgeSeconds // -1' \
        <<<"${STATUS_JSON}" \
        2>/dev/null
    )

    printf 'Status=%-7s age=%ss max=%ss\n' \
      "${STATUS}" \
      "${AGE}" \
      "${MAX_AGE}"

    if [[ "${STATUS}" == "STALE" ]]; then
        break
    fi

    NOW=$(date +%s)
    ELAPSED=$((NOW - START_TIME))

    if (( ELAPSED >= MAX_WAIT )); then

        echo
        echo "ERROR: timeout esperando estado STALE."
        exit 1

    fi

    sleep "${POLL_INTERVAL}"

done


# ============================================================
# 3 - CENTRAL
# ============================================================

echo
echo "=== [3/5] Validando Central ==="

CENTRAL_BODY=$(mktemp)

CENTRAL_HTTP=$(
  curl -sS \
    -o "${CENTRAL_BODY}" \
    -w '%{http_code}' \
    "${CENTRAL_URL}/health" \
    2>/dev/null || echo "000"
)

echo "Central HTTP : ${CENTRAL_HTTP}"
printf 'Central Body : '
cat "${CENTRAL_BODY}"
echo

rm -f "${CENTRAL_BODY}"


# ============================================================
# 4 - TECHNICAL
# ============================================================

echo
echo "=== [4/5] Validando disponibilidad técnica ==="

TECH_BODY=$(mktemp)

TECH_HTTP=$(
  curl -sS \
    -o "${TECH_BODY}" \
    -w '%{http_code}' \
    "${RETAIL_URL}/health" \
    2>/dev/null || echo "000"
)

echo "Technical HTTP : ${TECH_HTTP}"
printf 'Technical Body : '
cat "${TECH_BODY}"
echo

rm -f "${TECH_BODY}"


# ============================================================
# 5 - BUSINESS
# ============================================================

echo
echo "=== [5/5] Validando operación de negocio ==="

STATUS_JSON=$(
  curl -sS \
    "${RETAIL_URL}/api/status" \
    2>/dev/null || echo '{}'
)

echo "Retail status:"
echo "${STATUS_JSON}" | jq -c . 2>/dev/null || echo "${STATUS_JSON}"


BUSINESS_BODY=$(mktemp)

BUSINESS_HTTP=$(
  curl -sS \
    -o "${BUSINESS_BODY}" \
    -w '%{http_code}' \
    "${RETAIL_URL}/api/operation/${BUSINESS_SKU}" \
    2>/dev/null || echo "000"
)

echo
echo "Business HTTP : ${BUSINESS_HTTP}"

printf 'Business Body : '

if jq -e . "${BUSINESS_BODY}" >/dev/null 2>&1; then
    jq -c . "${BUSINESS_BODY}"
else
    cat "${BUSINESS_BODY}"
    echo
fi


BUSINESS_STATUS=$(
  jq -r '.status // "UNKNOWN"' \
    "${BUSINESS_BODY}" \
    2>/dev/null
)

BUSINESS_REASON=$(
  jq -r '.reason // ""' \
    "${BUSINESS_BODY}" \
    2>/dev/null
)

rm -f "${BUSINESS_BODY}"


# ============================================================
# FINAL VALIDATION
# ============================================================

RETAIL_STATE=$(
  jq -r '.status // "UNKNOWN"' \
    <<<"${STATUS_JSON}" \
    2>/dev/null
)


echo
echo "======================================================"

if [[ "${PERMS}" == "555" \
   && "${CENTRAL_HTTP}" == "200" \
   && "${TECH_HTTP}" == "200" \
   && "${RETAIL_STATE}" == "STALE" \
   && "${BUSINESS_HTTP}" == "503" \
   && "${BUSINESS_STATUS}" == "FAILED" ]]; then

    echo " BUSINESS IMPACT OBSERVATION = PASS"
    echo "======================================================"

    echo
    echo "TECHNICAL"
    echo "  Central service      : UP"
    echo "  Retail application   : UP"
    echo "  HTTP health          : 200"

    echo
    echo "BUSINESS"
    echo "  Critical file        : STALE"
    echo "  Business operation   : FAILED"
    echo "  HTTP operation       : 503"
    echo "  Reason               : ${BUSINESS_REASON}"

    echo
    echo "DEMO MESSAGE"
    echo "  Infrastructure and application are technically UP,"
    echo "  but the critical business process is unavailable."

    echo
    echo "Siguiente paso:"
    echo "  ./09-demo-recover.sh"

else

    echo " BUSINESS IMPACT OBSERVATION = CHECK REQUIRED"
    echo "======================================================"

    echo
    echo "PERMS           = ${PERMS}"
    echo "CENTRAL_HTTP    = ${CENTRAL_HTTP}"
    echo "TECH_HTTP       = ${TECH_HTTP}"
    echo "RETAIL_STATE    = ${RETAIL_STATE}"
    echo "BUSINESS_HTTP   = ${BUSINESS_HTTP}"
    echo "BUSINESS_STATUS = ${BUSINESS_STATUS}"

    exit 1

fi

echo

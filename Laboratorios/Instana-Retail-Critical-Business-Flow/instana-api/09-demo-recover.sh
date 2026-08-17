#!/usr/bin/env bash
set -uo pipefail

BASE_DIR="/opt/instana-demo/instana-api"

RETAIL_URL="http://192.168.252.33:18083"
CENTRAL_URL="http://192.168.252.35:18082"

BUSINESS_SKU="P00001"

MAX_WAIT=60
POLL_INTERVAL=5


# ============================================================
# LAB ENV
# ============================================================

if ! type bluebox_sudo >/dev/null 2>&1; then

    if ! source "${BASE_DIR}/00-load-lab-env.sh" >/dev/null 2>&1; then
        echo "ERROR: no fue posible cargar acceso a Bluebox."
        exit 1
    fi

fi


echo
echo "======================================================"
echo " RETAIL CRITICAL BUSINESS FLOW - RECOVERY"
echo "======================================================"


# ============================================================
# 1 - CURRENT STATE
# ============================================================

echo
echo "=== [1/5] Estado previo ==="

PERMS_BEFORE=$(
  bluebox_exec \
    'stat -c "%a" /opt/instana-demo/central/published' \
    2>/dev/null
)

echo "Central permissions : ${PERMS_BEFORE}"


# ============================================================
# 2 - RESTORE DISTRIBUTION
# ============================================================

echo
echo "=== [2/5] Restaurando distribución ==="

bluebox_sudo \
  /opt/instana-demo/scripts/recover-stale.sh


PERMS_AFTER=$(
  bluebox_exec \
    'stat -c "%a" /opt/instana-demo/central/published' \
    2>/dev/null
)

echo
echo "Central permissions : ${PERMS_AFTER}"

if [[ "${PERMS_AFTER}" != "755" ]]; then

    echo
    echo "ERROR: permisos no fueron restaurados."
    exit 1

fi


# ============================================================
# 3 - FORCE SOURCE
# ============================================================

echo
echo "=== [3/5] Forzando nueva publicación ==="

set +e
systemctl start instana-demo-source.service
SOURCE_RC=$?
set -e 2>/dev/null || true

echo "SOURCE rc=${SOURCE_RC}"


LAST_UPLOAD=$(
  grep 'event=upload_' \
    /opt/instana-demo/source/logs/source-job.log \
    2>/dev/null |
    tail -1 || true
)

echo "Último upload:"
echo "${LAST_UPLOAD}"


if [[ "${LAST_UPLOAD}" != *"event=upload_success"* ]]; then

    echo
    echo "ERROR: SOURCE no confirmó upload_success."
    exit 1

fi


# ============================================================
# 4 - WAIT UNTIL READY
# ============================================================

echo
echo "=== [4/5] Esperando recuperación del negocio ==="

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

    printf 'Status=%-7s age=%ss\n' \
      "${STATUS}" \
      "${AGE}"

    if [[ "${STATUS}" == "READY" ]]; then
        break
    fi

    NOW=$(date +%s)
    ELAPSED=$((NOW - START_TIME))

    if (( ELAPSED >= MAX_WAIT )); then

        echo
        echo "ERROR: timeout esperando READY."
        exit 1

    fi

    sleep "${POLL_INTERVAL}"

done


# ============================================================
# 5 - BUSINESS VALIDATION
# ============================================================

echo
echo "=== [5/5] Validando operación restaurada ==="

CENTRAL_BODY=$(mktemp)

CENTRAL_HTTP=$(
  curl -sS \
    -o "${CENTRAL_BODY}" \
    -w '%{http_code}' \
    "${CENTRAL_URL}/health" \
    2>/dev/null || echo "000"
)

echo "Central HTTP : ${CENTRAL_HTTP}"
rm -f "${CENTRAL_BODY}"


TECH_BODY=$(mktemp)

TECH_HTTP=$(
  curl -sS \
    -o "${TECH_BODY}" \
    -w '%{http_code}' \
    "${RETAIL_URL}/health" \
    2>/dev/null || echo "000"
)

echo "Technical HTTP : ${TECH_HTTP}"
rm -f "${TECH_BODY}"


BUSINESS_BODY=$(mktemp)

BUSINESS_HTTP=$(
  curl -sS \
    -o "${BUSINESS_BODY}" \
    -w '%{http_code}' \
    "${RETAIL_URL}/api/operation/${BUSINESS_SKU}" \
    2>/dev/null || echo "000"
)

BUSINESS_STATUS=$(
  jq -r '.status // "UNKNOWN"' \
    "${BUSINESS_BODY}" \
    2>/dev/null
)

echo "Business HTTP : ${BUSINESS_HTTP}"
printf 'Business Body : '

if jq -e . "${BUSINESS_BODY}" >/dev/null 2>&1; then
    jq -c . "${BUSINESS_BODY}"
else
    cat "${BUSINESS_BODY}"
    echo
fi

rm -f "${BUSINESS_BODY}"


echo
echo "======================================================"

if [[ "${PERMS_AFTER}" == "755" \
   && "${CENTRAL_HTTP}" == "200" \
   && "${TECH_HTTP}" == "200" \
   && "${STATUS}" == "READY" \
   && "${BUSINESS_HTTP}" == "200" \
   && "${BUSINESS_STATUS}" == "SUCCESS" ]]; then

    echo " BUSINESS RECOVERY = PASS"
    echo "======================================================"

    echo
    echo "Distribution       : ENABLED"
    echo "Critical file      : READY"
    echo "Central service    : UP"
    echo "Retail application : UP"
    echo "Business operation : SUCCESS"
    echo "HTTP operation     : 200"

    echo
    echo "DEMO MESSAGE"
    echo "  The business process has been restored"
    echo "  after recovering the file distribution path."

else

    echo " BUSINESS RECOVERY = CHECK REQUIRED"
    echo "======================================================"

    echo
    echo "PERMS            = ${PERMS_AFTER}"
    echo "CENTRAL_HTTP     = ${CENTRAL_HTTP}"
    echo "TECH_HTTP        = ${TECH_HTTP}"
    echo "RETAIL_STATE     = ${STATUS}"
    echo "BUSINESS_HTTP    = ${BUSINESS_HTTP}"
    echo "BUSINESS_STATUS  = ${BUSINESS_STATUS}"

    exit 1

fi

echo

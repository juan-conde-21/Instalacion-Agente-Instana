#!/usr/bin/env bash
set -uo pipefail

BASE_DIR="/opt/instana-demo/instana-api"

CENTRAL_URL="http://192.168.252.35:18082"
RETAIL_URL="http://192.168.252.33:18083"

BUSINESS_SKU="P00001"

if ! type bluebox_exec >/dev/null 2>&1; then
    source "${BASE_DIR}/00-load-lab-env.sh"
fi

echo
echo "======================================================"
echo " RETAIL CRITICAL BUSINESS FLOW - STATUS"
echo "======================================================"

echo
echo "=== SOURCE / BASTION ==="

SOURCE_SERVICE=$(
  systemctl is-active instana-demo-source.service 2>/dev/null || true
)

SOURCE_TIMER=$(
  systemctl is-active instana-demo-source.timer 2>/dev/null || true
)

echo "Service : ${SOURCE_SERVICE}"
echo "Timer   : ${SOURCE_TIMER}"

echo
echo "Last SOURCE events:"
tail -n 5 \
  /opt/instana-demo/source/logs/source-job.log \
  2>/dev/null || echo "SOURCE LOG unavailable"


echo
echo "=== CENTRAL / BLUEBOX ==="

BLUEBOX_STATE=$(
  bluebox_exec '
    FILE=/opt/instana-demo/central/published/promotions_current.csv
    DIR=/opt/instana-demo/central/published

    echo "PERMS=$(stat -c %a "$DIR")"

    if [[ -f "$FILE" ]]; then
        NOW=$(date +%s)
        MODIFIED=$(stat -c %Y "$FILE")
        AGE=$((NOW-MODIFIED))

        echo "FILE_AGE_SECONDS=$AGE"
        echo "FILE_SIZE=$(stat -c %s "$FILE")"
    else
        echo "FILE_AGE_SECONDS=NA"
        echo "FILE_SIZE=NA"
    fi
  ' 2>/dev/null
)

echo "${BLUEBOX_STATE}"

CENTRAL_TMP=$(mktemp)

CENTRAL_HTTP=$(
  curl -sS \
    -o "${CENTRAL_TMP}" \
    -w '%{http_code}' \
    "${CENTRAL_URL}/health" \
    2>/dev/null || echo "000"
)

echo "Central HTTP : ${CENTRAL_HTTP}"
printf 'Central Body : '
cat "${CENTRAL_TMP}"
echo

rm -f "${CENTRAL_TMP}"


echo
echo "=== RETAIL TECHNICAL ==="

RETAIL_HEALTH_TMP=$(mktemp)

RETAIL_HEALTH_HTTP=$(
  curl -sS \
    -o "${RETAIL_HEALTH_TMP}" \
    -w '%{http_code}' \
    "${RETAIL_URL}/health" \
    2>/dev/null || echo "000"
)

echo "Technical HTTP : ${RETAIL_HEALTH_HTTP}"
printf 'Technical Body : '
cat "${RETAIL_HEALTH_TMP}"
echo

rm -f "${RETAIL_HEALTH_TMP}"


echo
echo "=== RETAIL FILE STATUS ==="

RETAIL_STATUS_TMP=$(mktemp)

RETAIL_STATUS_HTTP=$(
  curl -sS \
    -o "${RETAIL_STATUS_TMP}" \
    -w '%{http_code}' \
    "${RETAIL_URL}/api/status" \
    2>/dev/null || echo "000"
)

echo "Status HTTP : ${RETAIL_STATUS_HTTP}"
printf 'Status Body : '

if jq -e . "${RETAIL_STATUS_TMP}" >/dev/null 2>&1; then
    jq -c . "${RETAIL_STATUS_TMP}"
else
    cat "${RETAIL_STATUS_TMP}"
    echo
fi

rm -f "${RETAIL_STATUS_TMP}"


echo
echo "=== BUSINESS OPERATION ==="

BUSINESS_TMP=$(mktemp)

BUSINESS_HTTP=$(
  curl -sS \
    -o "${BUSINESS_TMP}" \
    -w '%{http_code}' \
    "${RETAIL_URL}/api/operation/${BUSINESS_SKU}" \
    2>/dev/null || echo "000"
)

echo "Business HTTP : ${BUSINESS_HTTP}"
printf 'Business Body : '

if jq -e . "${BUSINESS_TMP}" >/dev/null 2>&1; then
    jq -c . "${BUSINESS_TMP}"
else
    cat "${BUSINESS_TMP}"
    echo
fi

rm -f "${BUSINESS_TMP}"


echo
echo "======================================================"

if [[ "${CENTRAL_HTTP}" == "200" \
   && "${RETAIL_HEALTH_HTTP}" == "200" \
   && "${BUSINESS_HTTP}" == "200" ]]; then

    echo " DEMO STATE = HEALTHY"

elif [[ "${CENTRAL_HTTP}" == "200" \
     && "${RETAIL_HEALTH_HTTP}" == "200" \
     && "${BUSINESS_HTTP}" == "503" ]]; then

    echo " DEMO STATE = BUSINESS IMPACT"
    echo
    echo " Technical availability : UP"
    echo " Business operation     : FAILED"

else

    echo " DEMO STATE = CHECK REQUIRED"

fi

echo "======================================================"
echo

#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/opt/instana-demo/instana-api"
STATE_DIR="${BASE_DIR}/state"
CONFIG_DIR="${BASE_DIR}/config"

APP_LABEL="RETAIL - Critical Promotions Flow"
ALERT_NAME="RETAIL - Business Transaction Failed"

INSTANA_URL="${INSTANA_URL:-https://unit0-ibm.instana-0.ibmdte.local}"

mkdir -p "${STATE_DIR}" "${CONFIG_DIR}"

if [[ -z "${INSTANA_TOKEN:-}" ]]; then
    IFS= read -rsp "Instana API Token: " INSTANA_TOKEN
    echo
fi

INSTANA_TOKEN="${INSTANA_TOKEN//$'\r'/}"

if [[ -z "${INSTANA_TOKEN}" ]]; then
    echo "ERROR: Instana API Token vacío"
    exit 1
fi


api_call() {

    local method="$1"
    local path="$2"
    local payload="${3:-}"

    API_BODY=$(mktemp)

    if [[ -n "${payload}" ]]; then

        API_CODE=$(curl -skS \
            -o "${API_BODY}" \
            -w '%{http_code}' \
            -X "${method}" \
            -H "Authorization: apiToken ${INSTANA_TOKEN}" \
            -H "Accept: application/json" \
            -H "Content-Type: application/json" \
            --data @"${payload}" \
            "${INSTANA_URL}${path}")

    else

        API_CODE=$(curl -skS \
            -o "${API_BODY}" \
            -w '%{http_code}' \
            -X "${method}" \
            -H "Authorization: apiToken ${INSTANA_TOKEN}" \
            -H "Accept: application/json" \
            "${INSTANA_URL}${path}")

    fi
}


echo
echo "=============================================="
echo " INSTANA - SYNTHETIC SMART ALERT"
echo "=============================================="


echo
echo "=== [1/5] Resolviendo IDs ==="

if [[ ! -s "${STATE_DIR}/application-id" ]]; then
    echo "ERROR: falta ${STATE_DIR}/application-id"
    echo "Ejecuta primero 01-create-application.sh"
    exit 1
fi

if [[ ! -s "${STATE_DIR}/synthetic-business-id" ]]; then
    echo "ERROR: falta ${STATE_DIR}/synthetic-business-id"
    echo "Ejecuta primero 02-sync-synthetics.sh"
    exit 1
fi

APP_ID=$(cat "${STATE_DIR}/application-id")
BUSINESS_TEST_ID=$(cat "${STATE_DIR}/synthetic-business-id")

echo "Application ID:"
echo "  ${APP_ID}"

echo
echo "Business Synthetic ID:"
echo "  ${BUSINESS_TEST_ID}"


echo
echo "=== [2/5] Generando Smart Alert ==="

cat > "${CONFIG_DIR}/alert-business.json" <<EOF
{
  "name": "${ALERT_NAME}",

  "description": "Critical retail business transaction is unavailable. Technical health can remain UP while the business operation fails.",

  "syntheticTestIds": [
    "${BUSINESS_TEST_ID}"
  ],

  "severity": 10,

  "tagFilterExpression": {
    "type": "TAG_FILTER",
    "name": "synthetic.applicationId",
    "stringValue": "${APP_ID}",
    "numberValue": null,
    "booleanValue": null,
    "key": null,
    "value": "${APP_ID}",
    "operator": "EQUALS",
    "entity": "NOT_APPLICABLE"
  },

  "rule": {
    "alertType": "failure",
    "metricName": "status",
    "aggregation": "SUM"
  },

  "alertChannelIds": [],

  "timeThreshold": {
    "type": "violationsInSequence",
    "violationsCount": 1
  },

  "customPayloadFields": []
}
EOF

jq . "${CONFIG_DIR}/alert-business.json"

echo
echo "Payload JSON OK"


echo
echo "=== [3/5] Consultando alertas existentes ==="

api_call \
  GET \
  "/api/events/settings/global-alert-configs/synthetics"

if [[ "${API_CODE}" != "200" ]]; then

    echo "ERROR consultando Synthetic Smart Alerts"
    echo "HTTP=${API_CODE}"
    cat "${API_BODY}"
    exit 1

fi

ALERT_ID=$(
    jq -r \
        --arg alert_name "${ALERT_NAME}" \
        '.[] |
         select(.name == $alert_name) |
         .id' \
        "${API_BODY}" \
    | head -1
)

rm -f "${API_BODY}"


echo
echo "=== [4/5] Create / Update ==="

if [[ -n "${ALERT_ID}" && "${ALERT_ID}" != "null" ]]; then

    echo "Smart Alert existente:"
    echo "${ALERT_ID}"
    echo
    echo "Actualizando..."

    api_call \
      POST \
      "/api/events/settings/global-alert-configs/synthetics/${ALERT_ID}" \
      "${CONFIG_DIR}/alert-business.json"

else

    echo "Smart Alert no existe."
    echo "Creando..."

    api_call \
      POST \
      "/api/events/settings/global-alert-configs/synthetics" \
      "${CONFIG_DIR}/alert-business.json"

fi


echo "HTTP=${API_CODE}"

if [[ ! "${API_CODE}" =~ ^2 ]]; then

    echo
    echo "ERROR:"
    cat "${API_BODY}"
    exit 1

fi


NEW_ALERT_ID=$(
    jq -r '.id // empty' "${API_BODY}"
)

if [[ -n "${NEW_ALERT_ID}" ]]; then
    ALERT_ID="${NEW_ALERT_ID}"
fi

echo
jq . "${API_BODY}"

rm -f "${API_BODY}"


if [[ -z "${ALERT_ID}" || "${ALERT_ID}" == "null" ]]; then
    echo "ERROR: no fue posible determinar Smart Alert ID"
    exit 1
fi

echo "${ALERT_ID}" > "${STATE_DIR}/synthetic-business-alert-id"


echo
echo "=== [5/5] Validando ==="

api_call \
  GET \
  "/api/events/settings/global-alert-configs/synthetics/${ALERT_ID}"

if [[ "${API_CODE}" != "200" ]]; then

    echo "ERROR validando Smart Alert"
    echo "HTTP=${API_CODE}"
    cat "${API_BODY}"
    exit 1

fi


jq '{
      id: .id,
      name: .name,
      description: .description,
      severity: .severity,
      syntheticTestIds: .syntheticTestIds,
      rule: .rule,
      timeThreshold: .timeThreshold,
      alertChannelIds: .alertChannelIds
    }' \
   "${API_BODY}"

rm -f "${API_BODY}"


echo
echo "Smart Alert:"
echo "  ${ALERT_NAME}"

echo
echo "Alert ID:"
echo "  ${ALERT_ID}"

echo
echo "Business Test:"
echo "  ${BUSINESS_TEST_ID}"

echo
echo "Threshold:"
echo "  1 consecutive failure"

echo
echo "Severity:"
echo "  CRITICAL"

echo
echo "=============================================="
echo " SYNTHETIC SMART ALERT READY"
echo "=============================================="

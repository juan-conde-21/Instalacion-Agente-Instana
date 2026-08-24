#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/opt/instana-demo/instana-api"
STATE_DIR="${BASE_DIR}/state"
CONFIG_DIR="${BASE_DIR}/config"

SLO_NAME="RETAIL - Technical Availability"
SLO_TARGET="0.995"

INSTANA_URL="${INSTANA_URL:-https://unit0-ibm.instana-0.ibmdte.local}"

if [[ -z "${INSTANA_TOKEN:-}" ]]; then
    IFS= read -rsp "Instana API Token: " INSTANA_TOKEN
    echo
fi

INSTANA_TOKEN="${INSTANA_TOKEN//$'\r'/}"

[[ -n "${INSTANA_TOKEN}" ]] || {
    echo "ERROR: Instana API Token vacío"
    exit 1
}

mkdir -p "${STATE_DIR}" "${CONFIG_DIR}"


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
echo " INSTANA - TECHNICAL SLO"
echo "=============================================="


echo
echo "=== [1/5] Resolviendo Technical Synthetic ==="

if [[ ! -s "${STATE_DIR}/synthetic-technical-id" ]]; then
    echo "ERROR: ejecutar primero 02-sync-synthetics.sh"
    exit 1
fi

TECHNICAL_TEST_ID=$(cat "${STATE_DIR}/synthetic-technical-id")

echo "Technical Synthetic ID:"
echo "  ${TECHNICAL_TEST_ID}"


echo
echo "=== [2/5] Generando SLO ==="

NOW_MS=$(date +%s%3N)

cat > "${CONFIG_DIR}/slo-technical.json" <<EOF
{
  "name": "${SLO_NAME}",
  "target": ${SLO_TARGET},
  "lastUpdated": ${NOW_MS},

  "entity": {
    "type": "synthetic",
    "syntheticTestIds": [
      "${TECHNICAL_TEST_ID}"
    ],
    "tagFilterExpression": {
      "type": "EXPRESSION",
      "logicalOperator": "AND",
      "elements": []
    }
  },

  "indicator": {
    "type": "eventBased",
    "threshold": 0,
    "operator": null,
    "aggregation": null,

    "badEventsFilter": {
      "type": "TAG_FILTER",
      "name": "call.erroneous",
      "stringValue": null,
      "numberValue": null,
      "booleanValue": true,
      "floatValue": null,
      "key": null,
      "value": null,
      "operator": "EQUALS",
      "entity": "NOT_APPLICABLE"
    },

    "goodEventsFilter": {
      "type": "TAG_FILTER",
      "name": "call.erroneous",
      "stringValue": null,
      "numberValue": null,
      "booleanValue": false,
      "floatValue": null,
      "key": null,
      "value": null,
      "operator": "EQUALS",
      "entity": "NOT_APPLICABLE"
    },

    "blueprint": "availability"
  },

  "timeWindow": {
    "type": "rolling",
    "duration": 1,
    "durationUnit": "week"
  },

  "tags": [
    "retail",
    "technical",
    "synthetic",
    "availability",
    "demo"
  ]
}
EOF

jq . "${CONFIG_DIR}/slo-technical.json" >/dev/null

echo "Payload JSON OK"


echo
echo "=== [3/5] Consultando SLO existente ==="

api_call GET "/api/settings/slo"

if [[ "${API_CODE}" != "200" ]]; then
    echo "ERROR consultando SLOs"
    echo "HTTP=${API_CODE}"
    cat "${API_BODY}"
    exit 1
fi

SLO_ID=$(
    jq -r \
        --arg slo_name "${SLO_NAME}" \
        '(.items // .)[] |
         select(.name == $slo_name) |
         .id' \
        "${API_BODY}" \
    | head -1
)

rm -f "${API_BODY}"


echo
echo "=== [4/5] Create / Reuse ==="

if [[ -n "${SLO_ID}" && "${SLO_ID}" != "null" ]]; then

    echo "SLO ya existe:"
    echo "  ${SLO_ID}"
    echo
    echo "Reutilizando configuración existente."

else

    echo "SLO no existe."
    echo "Creando..."

    api_call \
      POST \
      "/api/settings/slo" \
      "${CONFIG_DIR}/slo-technical.json"

    echo "HTTP=${API_CODE}"

    if [[ ! "${API_CODE}" =~ ^2 ]]; then
        echo
        echo "ERROR:"
        cat "${API_BODY}"
        exit 1
    fi

    SLO_ID=$(jq -r '.id // empty' "${API_BODY}")

    echo
    jq . "${API_BODY}"

    rm -f "${API_BODY}"
fi


if [[ -z "${SLO_ID}" || "${SLO_ID}" == "null" ]]; then
    echo "ERROR: no fue posible determinar SLO ID"
    exit 1
fi

echo "${SLO_ID}" > "${STATE_DIR}/slo-technical-id"


echo
echo "=== [5/5] Validando ==="

api_call GET "/api/settings/slo/${SLO_ID}"

if [[ "${API_CODE}" != "200" ]]; then
    echo "ERROR validando SLO"
    echo "HTTP=${API_CODE}"
    cat "${API_BODY}"
    exit 1
fi

jq '{
      id: .id,
      name: .name,
      target: .target,
      entityType: .entity.type,
      syntheticTestIds: .entity.syntheticTestIds,
      indicatorType: .indicator.type,
      blueprint: .indicator.blueprint,
      timeWindow: .timeWindow,
      tags: .tags
    }' "${API_BODY}"

rm -f "${API_BODY}"

echo
echo "SLO:"
echo "  ${SLO_NAME}"

echo
echo "Target:"
echo "  99.5%"

echo
echo "Technical Synthetic:"
echo "  ${TECHNICAL_TEST_ID}"

echo
echo "Window:"
echo "  Rolling 1 week"

echo
echo "=============================================="
echo " TECHNICAL SLO READY"
echo "=============================================="

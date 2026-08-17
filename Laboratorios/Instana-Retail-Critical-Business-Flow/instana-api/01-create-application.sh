#!/usr/bin/env bash
set -euo pipefail

APP_LABEL="RETAIL - Critical Promotions Flow"

BASE_DIR="/opt/instana-demo/instana-api"
STATE_DIR="${BASE_DIR}/state"
CONFIG_DIR="${BASE_DIR}/config"

mkdir -p "${STATE_DIR}" "${CONFIG_DIR}"

: "${INSTANA_URL:?ERROR: INSTANA_URL no definido}"
: "${INSTANA_TOKEN:?ERROR: INSTANA_TOKEN no definido}"

echo
echo "=============================================="
echo " INSTANA - APPLICATION PERSPECTIVE"
echo "=============================================="
echo

api_call() {

    local method="$1"
    local path="$2"
    local payload="${3:-}"

    local body
    body=$(mktemp)

    local code

    if [[ -n "${payload}" ]]; then

        code=$(curl -skS \
            -o "${body}" \
            -w '%{http_code}' \
            -X "${method}" \
            -H "Authorization: apiToken ${INSTANA_TOKEN}" \
            -H "Accept: application/json" \
            -H "Content-Type: application/json" \
            --data @"${payload}" \
            "${INSTANA_URL}${path}")

    else

        code=$(curl -skS \
            -o "${body}" \
            -w '%{http_code}' \
            -X "${method}" \
            -H "Authorization: apiToken ${INSTANA_TOKEN}" \
            -H "Accept: application/json" \
            "${INSTANA_URL}${path}")

    fi

    echo "${code}|${body}"
}


echo "=== [1/5] Consultando Application Perspectives ==="

result=$(api_call \
    GET \
    "/api/application-monitoring/settings/application")

code="${result%%|*}"
body="${result#*|}"

if [[ "${code}" != "200" ]]; then

    echo "ERROR: GET Application Perspectives"
    echo "HTTP=${code}"
    cat "${body}"
    exit 1

fi


APP_ID=$(
    jq -r \
        --arg app_label "${APP_LABEL}" \
        '.[] |
         select(.label == $app_label) |
         .id' \
        "${body}" \
    | head -1
)

rm -f "${body}"


echo
echo "=== [2/5] Generando definición ==="

cat > "${CONFIG_DIR}/application-retail.json" <<'EOF'
{
  "label": "RETAIL - Critical Promotions Flow",

  "scope": "INCLUDE_NO_DOWNSTREAM",

  "boundaryScope": "INBOUND",

  "tagFilterExpression": {

    "type": "EXPRESSION",

    "logicalOperator": "OR",

    "elements": [

      {
        "type": "TAG_FILTER",
        "name": "service.name",
        "stringValue": "central-service",
        "numberValue": null,
        "booleanValue": null,
        "key": null,
        "value": "central-service",
        "operator": "EQUALS",
        "entity": "DESTINATION"
      },

      {
        "type": "TAG_FILTER",
        "name": "service.name",
        "stringValue": "retail-app",
        "numberValue": null,
        "booleanValue": null,
        "key": null,
        "value": "retail-app",
        "operator": "EQUALS",
        "entity": "DESTINATION"
      }

    ]
  },

  "accessRules": [
    {
      "accessType": "READ_WRITE",
      "relationType": "GLOBAL",
      "relatedId": null
    }
  ]
}
EOF

jq . "${CONFIG_DIR}/application-retail.json"


echo
echo "=== [3/5] Create / Update ==="

if [[ -z "${APP_ID}" || "${APP_ID}" == "null" ]]; then

    echo "Application Perspective no existe."
    echo "Creando..."

    result=$(api_call \
        POST \
        "/api/application-monitoring/settings/application" \
        "${CONFIG_DIR}/application-retail.json")

else

    echo "Application Perspective existente:"
    echo "${APP_ID}"

    echo "Actualizando..."

    UPDATE_PAYLOAD=$(mktemp)

    jq \
        --arg app_id "${APP_ID}" \
        '. + {id: $app_id}' \
        "${CONFIG_DIR}/application-retail.json" \
        > "${UPDATE_PAYLOAD}"

    result=$(api_call \
        PUT \
        "/api/application-monitoring/settings/application/${APP_ID}" \
        "${UPDATE_PAYLOAD}")

    rm -f "${UPDATE_PAYLOAD}"

fi


code="${result%%|*}"
body="${result#*|}"

echo "HTTP=${code}"

if [[ ! "${code}" =~ ^2 ]]; then

    echo
    echo "ERROR:"
    cat "${body}"
    exit 1

fi

echo
jq . "${body}"


NEW_APP_ID=$(jq -r '.id // empty' "${body}")

rm -f "${body}"

if [[ -n "${NEW_APP_ID}" ]]; then
    APP_ID="${NEW_APP_ID}"
fi


if [[ -z "${APP_ID}" ]]; then
    echo "ERROR: no fue posible determinar Application ID"
    exit 1
fi


echo "${APP_ID}" \
  > "${STATE_DIR}/application-id"


echo
echo "=== [4/5] Validando ==="

result=$(api_call \
    GET \
    "/api/application-monitoring/settings/application/${APP_ID}")

code="${result%%|*}"
body="${result#*|}"

if [[ "${code}" != "200" ]]; then

    echo "ERROR durante validación."
    echo "HTTP=${code}"
    cat "${body}"
    exit 1

fi

jq '{
      id: .id,
      label: .label,
      scope: .scope,
      boundaryScope: .boundaryScope,
      filter: .tagFilterExpression
    }' \
   "${body}"

rm -f "${body}"


echo
echo "=== [5/5] Resultado ==="
echo
echo "Application Perspective:"
echo "${APP_LABEL}"
echo
echo "Application ID:"
echo "${APP_ID}"
echo

echo "Guardado en:"
echo "${STATE_DIR}/application-id"

echo
echo "=============================================="
echo " APPLICATION PERSPECTIVE READY"
echo "=============================================="

#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/opt/instana-demo/instana-api"
STATE_DIR="${BASE_DIR}/state"
CONFIG_DIR="${BASE_DIR}/config"

DASHBOARD_TITLE="RETAIL - Critical Business Flow"

INSTANA_URL="${INSTANA_URL:-https://unit0-ibm.instana-0.ibmdte.local}"

DASHBOARD_USER_EMAIL="${DASHBOARD_USER_EMAIL:-admin@instana.local}"

mkdir -p "${STATE_DIR}" "${CONFIG_DIR}"


# ------------------------------------------------------------
# TOKEN
# ------------------------------------------------------------

if [[ -z "${INSTANA_TOKEN:-}" ]]; then
    IFS= read -rsp "Instana API Token: " INSTANA_TOKEN
    echo
fi

INSTANA_TOKEN="${INSTANA_TOKEN//$'\r'/}"

if [[ -z "${INSTANA_TOKEN}" ]]; then
    echo "ERROR: Instana API Token vacío"
    exit 1
fi


# ------------------------------------------------------------
# API TOKEN NAME
# ------------------------------------------------------------

if [[ -z "${DASHBOARD_API_TOKEN_NAME:-}" ]]; then

    echo
    echo "API Tokens disponibles para Custom Dashboards:"
    echo

    TMP_TOKENS=$(mktemp)

    HTTP_CODE=$(curl -skS \
        -o "${TMP_TOKENS}" \
        -w '%{http_code}' \
        -H "Authorization: apiToken ${INSTANA_TOKEN}" \
        -H "Accept: application/json" \
        "${INSTANA_URL}/api/custom-dashboard/shareable-api-tokens")

    if [[ "${HTTP_CODE}" != "200" ]]; then
        echo "ERROR consultando API Tokens HTTP=${HTTP_CODE}"
        cat "${TMP_TOKENS}"
        exit 1
    fi

    jq -r '.[].name' "${TMP_TOKENS}"

    echo
    IFS= read -rp "Nombre del API Token usado para este lab: " \
        DASHBOARD_API_TOKEN_NAME

    rm -f "${TMP_TOKENS}"
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
echo " INSTANA - BUSINESS DASHBOARD"
echo "=============================================="


# ------------------------------------------------------------
# 1 - USER
# ------------------------------------------------------------

echo
echo "=== [1/6] Resolviendo propietario ==="

api_call GET "/api/custom-dashboard/shareable-users"

if [[ "${API_CODE}" != "200" ]]; then
    echo "ERROR HTTP=${API_CODE}"
    cat "${API_BODY}"
    exit 1
fi

USER_ID=$(
    jq -r \
        --arg user_email "${DASHBOARD_USER_EMAIL}" \
        '.[] |
         select(.email == $user_email) |
         .id' \
        "${API_BODY}" \
    | head -1
)

rm -f "${API_BODY}"

if [[ -z "${USER_ID}" || "${USER_ID}" == "null" ]]; then
    echo "ERROR: usuario ${DASHBOARD_USER_EMAIL} no encontrado"
    exit 1
fi

echo "User:"
echo "  ${DASHBOARD_USER_EMAIL}"
echo "ID:"
echo "  ${USER_ID}"


# ------------------------------------------------------------
# 2 - API TOKEN
# ------------------------------------------------------------

echo
echo "=== [2/6] Resolviendo API Token ==="

api_call GET "/api/custom-dashboard/shareable-api-tokens"

if [[ "${API_CODE}" != "200" ]]; then
    echo "ERROR HTTP=${API_CODE}"
    cat "${API_BODY}"
    exit 1
fi

TOKEN_ID=$(
    jq -r \
        --arg token_name "${DASHBOARD_API_TOKEN_NAME}" \
        '.[] |
         select(.name == $token_name) |
         .id' \
        "${API_BODY}" \
    | head -1
)

rm -f "${API_BODY}"

if [[ -z "${TOKEN_ID}" || "${TOKEN_ID}" == "null" ]]; then
    echo "ERROR: API Token '${DASHBOARD_API_TOKEN_NAME}' no encontrado"
    exit 1
fi

echo "API Token:"
echo "  ${DASHBOARD_API_TOKEN_NAME}"
echo "Internal ID:"
echo "  ${TOKEN_ID}"


# ------------------------------------------------------------
# 3 - EXISTING DASHBOARD
# ------------------------------------------------------------

echo
echo "=== [3/6] Consultando dashboard existente ==="

api_call GET \
  "/api/custom-dashboard?query=RETAIL&page=1&pageSize=100&withTotalHits=true"

if [[ "${API_CODE}" != "200" ]]; then
    echo "ERROR HTTP=${API_CODE}"
    cat "${API_BODY}"
    exit 1
fi

DASHBOARD_ID=$(
    jq -r \
        --arg dashboard_title "${DASHBOARD_TITLE}" \
        '(.items // .)[] |
         select(.title == $dashboard_title) |
         .id' \
        "${API_BODY}" \
    | head -1
)

rm -f "${API_BODY}"


# ------------------------------------------------------------
# 4 - PAYLOAD
# ------------------------------------------------------------

echo
echo "=== [4/6] Generando dashboard ==="

cat > "${CONFIG_DIR}/dashboard-base.json" <<EOF
{
  "title": "${DASHBOARD_TITLE}",

  "accessRules": [
    {
      "accessType": "READ_WRITE",
      "relationType": "USER",
      "relatedId": "${USER_ID}"
    },
    {
      "accessType": "READ_WRITE",
      "relationType": "API_TOKEN",
      "relatedId": "${TOKEN_ID}"
    }
  ],

  "widgets": []
}
EOF

jq . "${CONFIG_DIR}/dashboard-base.json"

echo
echo "Payload JSON OK"


# ------------------------------------------------------------
# 5 - CREATE / UPDATE
# ------------------------------------------------------------

echo
echo "=== [5/6] Create / Update ==="

if [[ -n "${DASHBOARD_ID}" && "${DASHBOARD_ID}" != "null" ]]; then

    echo "Dashboard existente:"
    echo "  ${DASHBOARD_ID}"

    echo "Actualizando..."

    api_call \
      PUT \
      "/api/custom-dashboard/${DASHBOARD_ID}" \
      "${CONFIG_DIR}/dashboard-base.json"

else

    echo "Dashboard no existe."
    echo "Creando..."

    api_call \
      POST \
      "/api/custom-dashboard" \
      "${CONFIG_DIR}/dashboard-base.json"

fi


echo "HTTP=${API_CODE}"

if [[ ! "${API_CODE}" =~ ^2 ]]; then
    echo
    echo "ERROR:"
    cat "${API_BODY}"
    exit 1
fi


NEW_ID=$(jq -r '.id // empty' "${API_BODY}")

if [[ -n "${NEW_ID}" ]]; then
    DASHBOARD_ID="${NEW_ID}"
fi

echo
jq . "${API_BODY}"

rm -f "${API_BODY}"


if [[ -z "${DASHBOARD_ID}" ]]; then
    echo "ERROR: no fue posible determinar Dashboard ID"
    exit 1
fi

echo "${DASHBOARD_ID}" > "${STATE_DIR}/dashboard-id"


# ------------------------------------------------------------
# 6 - REAL VALIDATION
# ------------------------------------------------------------

echo
echo "=== [6/6] Validando persistencia ==="

sleep 1

api_call GET \
  "/api/custom-dashboard?query=RETAIL&page=1&pageSize=100&withTotalHits=true"

if [[ "${API_CODE}" != "200" ]]; then
    echo "ERROR validando dashboard HTTP=${API_CODE}"
    cat "${API_BODY}"
    exit 1
fi


VALID_DASHBOARD=$(
    jq -c \
        --arg dashboard_id "${DASHBOARD_ID}" \
        '(.items // .)[] |
         select(.id == $dashboard_id)' \
        "${API_BODY}"
)


if [[ -z "${VALID_DASHBOARD}" ]]; then

    echo
    echo "ERROR:"
    echo "Instana respondió al POST/PUT pero el dashboard"
    echo "NO aparece entre los dashboards accesibles."
    echo
    echo "Dashboard ID:"
    echo "  ${DASHBOARD_ID}"

    exit 1
fi


echo "${VALID_DASHBOARD}" \
  | jq '{
      id: .id,
      title: .title,
      writable: .writable,
      ownerId: .ownerId,
      widgets: ((.widgets // []) | length)
    }'


echo "${VALID_DASHBOARD}" \
  | jq . \
  > "${CONFIG_DIR}/dashboard-current.json"

rm -f "${API_BODY}"


echo
echo "Dashboard:"
echo "  ${DASHBOARD_TITLE}"

echo
echo "Dashboard ID:"
echo "  ${DASHBOARD_ID}"

echo
echo "User owner/editor:"
echo "  ${DASHBOARD_USER_EMAIL}"

echo
echo "API Token editor:"
echo "  ${DASHBOARD_API_TOKEN_NAME}"

echo
echo "=============================================="
echo " BUSINESS DASHBOARD BASE READY"
echo "=============================================="

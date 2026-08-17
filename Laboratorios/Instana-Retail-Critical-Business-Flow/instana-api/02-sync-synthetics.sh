#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/opt/instana-demo/instana-api"
STATE_DIR="${BASE_DIR}/state"
CONFIG_DIR="${BASE_DIR}/config"

APP_LABEL="RETAIL - Critical Promotions Flow"
POP_LABEL="instana-critical-demo-pop"

TECH_LABEL="RETAIL - Technical Availability"
BUSINESS_LABEL="RETAIL - Business Transaction"

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
echo " INSTANA - SYNTHETIC TESTS"
echo "=============================================="


echo
echo "=== [1/6] Resolviendo Application ID ==="

APP_ID=""

if [[ -s "${STATE_DIR}/application-id" ]]; then
    APP_ID=$(cat "${STATE_DIR}/application-id")
fi

if [[ -z "${APP_ID}" ]]; then

    api_call GET "/api/application-monitoring/settings/application"

    if [[ "${API_CODE}" != "200" ]]; then
        echo "ERROR obteniendo Applications HTTP=${API_CODE}"
        cat "${API_BODY}"
        exit 1
    fi

    APP_ID=$(
        jq -r \
            --arg app_name "${APP_LABEL}" \
            '.[] |
             select(.label == $app_name) |
             .id' \
            "${API_BODY}" \
        | head -1
    )

    rm -f "${API_BODY}"
fi


if [[ -z "${APP_ID}" || "${APP_ID}" == "null" ]]; then
    echo "ERROR: Application Perspective no encontrada"
    exit 1
fi

echo "Application:"
echo "${APP_LABEL}"
echo "ID=${APP_ID}"

echo "${APP_ID}" > "${STATE_DIR}/application-id"


echo
echo "=== [2/6] Resolviendo Synthetic Location ==="

api_call GET "/api/synthetics/settings/locations"

if [[ "${API_CODE}" != "200" ]]; then
    echo "ERROR obteniendo Synthetic Locations HTTP=${API_CODE}"
    cat "${API_BODY}"
    exit 1
fi


LOCATION_ID=$(
    jq -r \
        --arg pop_name "${POP_LABEL}" \
        '.[] |
         select(.label == $pop_name and .status == "Online") |
         .id' \
        "${API_BODY}" \
    | head -1
)

rm -f "${API_BODY}"


if [[ -z "${LOCATION_ID}" || "${LOCATION_ID}" == "null" ]]; then
    echo "ERROR: PoP ${POP_LABEL} no encontrado u Offline"
    exit 1
fi

echo "PoP:"
echo "${POP_LABEL}"
echo "ID=${LOCATION_ID}"

echo "${LOCATION_ID}" > "${STATE_DIR}/synthetic-location-id"


echo
echo "=== [3/6] Generando payloads ==="


cat > "${CONFIG_DIR}/synthetic-technical.json" <<EOF
{
  "label": "${TECH_LABEL}",
  "applicationId": "${APP_ID}",
  "active": true,
  "testFrequency": 1,
  "playbackMode": "Simultaneous",
  "locations": [
    "${LOCATION_ID}"
  ],
  "configuration": {
    "syntheticType": "HTTPAction",
    "markSyntheticCall": true,
    "retries": 0,
    "retryInterval": 1,
    "timeout": "0m",
    "url": "http://192.168.252.33:18083/health",
    "operation": "GET",
    "validationString": "\\"status\\":\\"UP\\"",
    "followRedirect": true,
    "allowInsecure": true,
    "expectStatus": 200
  },
  "customProperties": {},
  "rbacTags": []
}
EOF


cat > "${CONFIG_DIR}/synthetic-business.json" <<EOF
{
  "label": "${BUSINESS_LABEL}",
  "applicationId": "${APP_ID}",
  "active": true,
  "testFrequency": 1,
  "playbackMode": "Simultaneous",
  "locations": [
    "${LOCATION_ID}"
  ],
  "configuration": {
    "syntheticType": "HTTPAction",
    "markSyntheticCall": true,
    "retries": 0,
    "retryInterval": 1,
    "timeout": "0m",
    "url": "http://192.168.252.33:18083/api/operation/P00001",
    "operation": "GET",
    "validationString": "\\"status\\":\\"SUCCESS\\"",
    "followRedirect": true,
    "allowInsecure": true,
    "expectStatus": 200
  },
  "customProperties": {},
  "rbacTags": []
}
EOF


jq . "${CONFIG_DIR}/synthetic-technical.json" >/dev/null
jq . "${CONFIG_DIR}/synthetic-business.json" >/dev/null

echo "Payloads JSON OK"


echo
echo "=== [4/6] Consultando tests existentes ==="

DISCOVERY_AVAILABLE=0

TESTS_FILE="${CONFIG_DIR}/synthetic-tests-current.json"

printf '[]\n' > "${TESTS_FILE}"

api_call GET "/api/synthetics/settings/tests"

if [[ "${API_CODE}" == "200" ]]; then

    cp "${API_BODY}" "${TESTS_FILE}"
    DISCOVERY_AVAILABLE=1

    rm -f "${API_BODY}"

    echo "Synthetic discovery: AVAILABLE"

elif [[ "${API_CODE}" == "403" ]]; then

    echo "WARN: Synthetic Tests LIST devolvió HTTP=403."
    echo "Continuando en modo bootstrap mediante POST + GET directo."

    rm -f "${API_BODY}"

else

    echo "ERROR obteniendo Synthetic Tests HTTP=${API_CODE}"
    cat "${API_BODY}"

    rm -f "${API_BODY}"

    exit 1
fi


find_test_by_label() {

    local test_label="$1"

    jq -r \
      --arg test_name "${test_label}" \
      '
      if type == "array" then
        .[]
      else
        (.items // [])[]
      end
      |
      select((.label // "") == $test_name)
      |
      .id
      ' \
      "${TESTS_FILE}" \
      | head -1
}


sync_test() {

    local test_label="$1"
    local payload="$2"
    local state_file="$3"

    local test_id=""
    local state_id=""
    local object_exists=0
    local tmp_payload=""


    echo
    echo "----------------------------------------------"
    echo "${test_label}"
    echo "----------------------------------------------"


    # ========================================================
    # 1. Intentar recuperar por State ID
    # ========================================================

    if [[ -s "${state_file}" ]]; then

        state_id=$(
            tr -d '\r\n' < "${state_file}"
        )

        if [[ -n "${state_id}" ]]; then

            echo "State ID encontrado: ${state_id}"
            echo "Validando ID directamente..."

            api_call \
                GET \
                "/api/synthetics/settings/tests/${state_id}"

            case "${API_CODE}" in

                200)

                    test_id="${state_id}"
                    object_exists=1

                    echo "Objeto existente confirmado."

                    rm -f "${API_BODY}"
                    ;;

                404)

                    echo "State ID ya no existe."
                    echo "Se recreará el test."

                    rm -f "${state_file}"
                    rm -f "${API_BODY}"
                    ;;

                *)

                    echo "ERROR validando State ID HTTP=${API_CODE}"
                    cat "${API_BODY}"

                    rm -f "${API_BODY}"

                    exit 1
                    ;;
            esac
        fi
    fi


    # ========================================================
    # 2. Discovery por label cuando LIST está disponible
    # ========================================================

    if [[ -z "${test_id}" \
       && "${DISCOVERY_AVAILABLE}" == "1" ]]; then

        test_id=$(
            find_test_by_label "${test_label}"
        )

        if [[ -n "${test_id}" \
           && "${test_id}" != "null" ]]; then

            echo "Encontrado por label: ${test_id}"

            object_exists=1
        fi
    fi


    # ========================================================
    # 3. Update
    # ========================================================

    if (( object_exists == 1 )); then

        echo "Actualizando..."

        tmp_payload=$(mktemp)

        jq \
          --arg test_id "${test_id}" \
          '. + {id: $test_id}' \
          "${payload}" \
          > "${tmp_payload}"

        api_call \
            PUT \
            "/api/synthetics/settings/tests/${test_id}" \
            "${tmp_payload}"

        rm -f "${tmp_payload}"

        if [[ ! "${API_CODE}" =~ ^2 ]]; then

            echo "ERROR actualizando test HTTP=${API_CODE}"
            cat "${API_BODY}"

            rm -f "${API_BODY}"

            exit 1
        fi

        rm -f "${API_BODY}"


    # ========================================================
    # 4. Create / Bootstrap
    # ========================================================

    else

        echo "No existe."
        echo "Creando..."

        api_call \
            POST \
            "/api/synthetics/settings/tests" \
            "${payload}"

        if [[ ! "${API_CODE}" =~ ^2 ]]; then

            echo "ERROR creando test HTTP=${API_CODE}"
            cat "${API_BODY}"

            rm -f "${API_BODY}"

            exit 1
        fi

        test_id=$(
            jq -r '.id // empty' "${API_BODY}"
        )

        rm -f "${API_BODY}"


        # ----------------------------------------------------
        # Fallback:
        # solo es posible si LIST está disponible.
        # ----------------------------------------------------

        if [[ -z "${test_id}" ]]; then

            if [[ "${DISCOVERY_AVAILABLE}" == "1" ]]; then

                sleep 1

                api_call GET "/api/synthetics/settings/tests"

                if [[ "${API_CODE}" != "200" ]]; then

                    echo "ERROR: POST no devolvió ID y LIST HTTP=${API_CODE}"
                    cat "${API_BODY}"

                    rm -f "${API_BODY}"

                    exit 1
                fi

                cp "${API_BODY}" "${TESTS_FILE}"

                rm -f "${API_BODY}"

                test_id=$(
                    find_test_by_label "${test_label}"
                )

            else

                echo "ERROR: POST fue exitoso pero no devolvió Test ID."
                echo "Synthetic LIST tampoco está disponible para fallback."

                exit 1
            fi
        fi
    fi


    if [[ -z "${test_id}" || "${test_id}" == "null" ]]; then
        echo "ERROR: no se pudo determinar Test ID"
        exit 1
    fi


    echo "${test_id}" > "${state_file}"

    echo "ID=${test_id}"

    echo "Validando..."

    api_call \
        GET \
        "/api/synthetics/settings/tests/${test_id}"

    if [[ "${API_CODE}" != "200" ]]; then
        echo "ERROR validando test HTTP=${API_CODE}"
        cat "${API_BODY}"
        exit 1
    fi


    jq '{
      "id": .id,
      "label": .label,
      "applicationId": .applicationId,
      "active": .active,
      "frequency": .testFrequency,
      "locations": .locationLabels,
      "type": .configuration.syntheticType,
      "url": .configuration.url,
      "expectedStatus": .configuration.expectStatus,
      "validationString": .configuration.validationString
    }' "${API_BODY}"

    rm -f "${API_BODY}"
}


echo
echo "=== [5/6] Create / Update ==="

sync_test \
    "${TECH_LABEL}" \
    "${CONFIG_DIR}/synthetic-technical.json" \
    "${STATE_DIR}/synthetic-technical-id"

sync_test \
    "${BUSINESS_LABEL}" \
    "${CONFIG_DIR}/synthetic-business.json" \
    "${STATE_DIR}/synthetic-business-id"


rm -f "${TESTS_FILE}" 2>/dev/null || true


echo
echo "=== [6/6] Resultado ==="
echo

echo "Application:"
echo "  ${APP_LABEL}"
echo "  $(cat "${STATE_DIR}/application-id")"

echo
echo "Synthetic Location:"
echo "  ${POP_LABEL}"
echo "  $(cat "${STATE_DIR}/synthetic-location-id")"

echo
echo "Technical Synthetic:"
echo "  ${TECH_LABEL}"
echo "  $(cat "${STATE_DIR}/synthetic-technical-id")"

echo
echo "Business Synthetic:"
echo "  ${BUSINESS_LABEL}"
echo "  $(cat "${STATE_DIR}/synthetic-business-id")"

echo
echo "=============================================="
echo " SYNTHETIC TESTS READY"
echo "=============================================="

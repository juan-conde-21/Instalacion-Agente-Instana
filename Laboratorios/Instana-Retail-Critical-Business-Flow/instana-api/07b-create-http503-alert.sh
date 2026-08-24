#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/opt/instana-demo/instana-api"
STATE_DIR="${BASE_DIR}/state"
OUT_DIR="${STATE_DIR}/website-alerts"

source "${BASE_DIR}/00-load-instana-env.sh"

mkdir -p "${OUT_DIR}"

WEBSITE_ID="$(
  tr -d '\r\n' < "${STATE_DIR}/website-id"
)"

WEBSITE_NAME="$(
  jq -r '.name' "${STATE_DIR}/website.json"
)"

ALERT_NAME="RETAIL - NOVA - HTTP 503"

AUTH="Authorization: apiToken ${INSTANA_TOKEN}"

CURRENT="${OUT_DIR}/website-alert-configs.json"
REQUEST="${OUT_DIR}/http503-request.json"
RESPONSE="${OUT_DIR}/http503-response.json"
CANONICAL="${OUT_DIR}/http503-canonical.json"
ID_FILE="${STATE_DIR}/website-alert-http503-id"


echo
echo "========================================================"
echo " INSTANA API | CREATE WEBSITE SMART ALERT"
echo "========================================================"
echo
printf " Website : %s\n" "${WEBSITE_NAME}"
printf " Alert   : %s\n" "${ALERT_NAME}"
echo


# --------------------------------------------------------
# Consultar configuración existente
# --------------------------------------------------------

curl -ksSf \
  -H "${AUTH}" \
  -H "Accept: application/json" \
  "${INSTANA_URL}/api/events/settings/website-alert-configs?websiteId=${WEBSITE_ID}" \
  > "${CURRENT}"


existing_id="$(
  jq -r \
    --arg name "${ALERT_NAME}" \
    --arg wid "${WEBSITE_ID}" '
      (
        if type == "array"
        then .
        else (.items // .configs // [])
        end
      )
      | .[]
      | select(
          .name == $name
          and
          .websiteId == $wid
        )
      | .id
    ' "${CURRENT}" \
    | head -1
)"


if [[ -n "${existing_id}" ]]; then

  echo "[OK] Smart Alert ya existe"
  echo "     ID: ${existing_id}"

  printf '%s\n' \
    "${existing_id}" \
    > "${ID_FILE}"

  jq \
    --arg id "${existing_id}" '
      (
        if type == "array"
        then .
        else (.items // .configs // [])
        end
      )
      | .[]
      | select(.id == $id)
    ' "${CURRENT}" \
    > "${CANONICAL}"

  echo
  echo "Configuración actual"
  echo "--------------------------------------------------------"
  jq . "${CANONICAL}"

  echo
  echo "--------------------------------------------------------"
  echo " WEBSITE SMART ALERT : READY"
  echo "--------------------------------------------------------"

  exit 0
fi


# --------------------------------------------------------
# Construir payload
# --------------------------------------------------------
#
# Regla:
#
#   Website        RETAIL - NOVA Market
#   HTTP path      /api/checkout
#   HTTP method    POST
#   HTTP status    503
#   Métrica        http5xx
#   Threshold      > 0
#   Granularidad   60 segundos
#
# Un solo checkout 503 en una ventana de 60s es suficiente
# para generar la violación.
#

jq -n \
  --arg name "${ALERT_NAME}" \
  --arg wid "${WEBSITE_ID}" '
  {
    name: $name,

    description:
      "Detecta respuestas HTTP 503 observadas por usuarios durante el checkout de NOVA Market.",

    websiteId: $wid,

    enabled: true,

    triggering: false,

    alertChannelIds: [],

    customPayloadFields: [],

    tagFilters: [
      {
        name: "beacon.http.path",
        operator: "EQUALS",
        value: "/api/checkout"
      },
      {
        name: "beacon.http.method",
        operator: "EQUALS",
        value: "POST"
      }
    ],

    granularity: 300000,

    rules: [
      {
        rule: {
          alertType: "statusCode",
          metricName: "httpxxx",
          aggregation: "SUM",
          operator: "EQUALS",
          value: "503"
        },

        thresholdOperator: ">",

        thresholds: {
          WARNING: {
            type: "staticThreshold",
            value: 0
          }
        }
      }
    ],

    timeThreshold: {
      type: "violationsInSequence",
      timeWindow: 300000
    }
  }
' > "${REQUEST}"


echo "Configuración solicitada"
echo "--------------------------------------------------------"
jq . "${REQUEST}"

echo
echo "[INFO] Creando Smart Alert..."


HTTP_CODE="$(
  curl -ksS \
    -o "${RESPONSE}" \
    -w '%{http_code}' \
    -X POST \
    -H "${AUTH}" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    --data @"${REQUEST}" \
    "${INSTANA_URL}/api/events/settings/website-alert-configs" \
    || true
)"


case "${HTTP_CODE}" in
  200|201)
    echo "[OK] Instana aceptó la configuración (HTTP ${HTTP_CODE})"
    ;;

  *)
    echo
    echo "[ERROR] Instana rechazó la Smart Alert."
    echo "        HTTP ${HTTP_CODE}"
    echo

    echo "Respuesta"
    echo "--------------------------------------------------------"

    if [[ -s "${RESPONSE}" ]]; then
      jq . "${RESPONSE}" 2>/dev/null ||
        cat "${RESPONSE}"
    else
      echo "(sin cuerpo)"
    fi

    echo
    echo "Payload conservado en:"
    echo " ${REQUEST}"
    echo
    echo "No se modificó ninguna configuración existente."

    exit 2
    ;;
esac


# --------------------------------------------------------
# Leer la configuración nuevamente desde Instana
# --------------------------------------------------------

curl -ksSf \
  -H "${AUTH}" \
  -H "Accept: application/json" \
  "${INSTANA_URL}/api/events/settings/website-alert-configs?websiteId=${WEBSITE_ID}" \
  > "${CURRENT}"


created_id="$(
  jq -r \
    --arg name "${ALERT_NAME}" \
    --arg wid "${WEBSITE_ID}" '
      (
        if type == "array"
        then .
        else (.items // .configs // [])
        end
      )
      | .[]
      | select(
          .name == $name
          and
          .websiteId == $wid
        )
      | .id
    ' "${CURRENT}" \
    | head -1
)"


if [[ -z "${created_id}" ]]; then

  echo "[ERROR] POST fue aceptado pero no encuentro la alerta al releerla."
  echo
  echo "Respuesta original:"
  jq . "${RESPONSE}" 2>/dev/null ||
    cat "${RESPONSE}"

  exit 3
fi


printf '%s\n' \
  "${created_id}" \
  > "${ID_FILE}"


jq \
  --arg id "${created_id}" '
    (
      if type == "array"
      then .
      else (.items // .configs // [])
      end
    )
    | .[]
    | select(.id == $id)
  ' "${CURRENT}" \
  > "${CANONICAL}"


echo
echo "========================================================"
echo " SMART ALERT CREADA"
echo "========================================================"
echo
printf " Name : %s\n" "${ALERT_NAME}"
printf " ID   : %s\n" "${created_id}"

echo
echo "Configuración canónica devuelta por Instana"
echo "--------------------------------------------------------"

jq . "${CANONICAL}"

echo
echo "Estado persistido"
echo "--------------------------------------------------------"
echo " ${ID_FILE}"
echo " ${REQUEST}"
echo " ${RESPONSE}"
echo " ${CANONICAL}"

echo
echo "--------------------------------------------------------"
echo " WEBSITE SMART ALERT : READY"
echo "--------------------------------------------------------"

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

ALERT_NAME="RETAIL - NOVA - Checkout Failed"

AUTH="Authorization: apiToken ${INSTANA_TOKEN}"

CURRENT="${OUT_DIR}/website-alert-configs.json"
REQUEST="${OUT_DIR}/checkout-failed-request.json"
RESPONSE="${OUT_DIR}/checkout-failed-response.json"
CANONICAL="${OUT_DIR}/checkout-failed-canonical.json"
ID_FILE="${STATE_DIR}/website-alert-checkout-failed-id"

echo
echo "========================================================"
echo " INSTANA API | CREATE BUSINESS SMART ALERT"
echo "========================================================"
echo
echo " Alert   : ${ALERT_NAME}"
echo " Website : ${WEBSITE_ID}"
echo


# --------------------------------------------------------
# Idempotencia
# --------------------------------------------------------

curl -ksSf \
  -H "${AUTH}" \
  -H "Accept: application/json" \
  "${INSTANA_URL}/api/events/settings/website-alert-configs" \
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
    ' "${CURRENT}" |
  head -1
)"

if [[ -n "${existing_id}" ]]; then

  echo "[OK] Smart Alert ya existe"
  echo "     ID: ${existing_id}"

  printf '%s\n' "${existing_id}" > "${ID_FILE}"

  curl -ksSf \
    -H "${AUTH}" \
    "${INSTANA_URL}/api/events/settings/website-alert-configs/${existing_id}" \
    > "${CANONICAL}"

  jq . "${CANONICAL}"

  echo
  echo "--------------------------------------------------------"
  echo " BUSINESS SMART ALERT : READY"
  echo "--------------------------------------------------------"

  exit 0
fi


# --------------------------------------------------------
# Configuración
# --------------------------------------------------------

jq -n \
  --arg name "${ALERT_NAME}" \
  --arg wid "${WEBSITE_ID}" '
{
  name: $name,

  description:
    "Detecta intentos de compra fallidos reportados directamente por la experiencia digital de NOVA Market.",

  websiteId: $wid,

  enabled: true,

  triggering: false,

  alertChannelIds: [],

  customPayloadFields: [],

  tagFilters: [
    {
      name: "beacon.customEvent.name",
      operator: "EQUALS",
      value: "NOVA Checkout Failed"
    }
  ],

  granularity: 60000,

  rules: [
    {
      rule: {
        alertType: "customEvent",
        metricName: "beaconCount",
        aggregation: "SUM",
        customEventName: "NOVA Checkout Failed"
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
    timeWindow: 60000
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
    echo "[ERROR] Instana rechazó la configuración."
    echo "        HTTP ${HTTP_CODE}"
    echo

    if [[ -s "${RESPONSE}" ]]; then
      jq . "${RESPONSE}" 2>/dev/null ||
        cat "${RESPONSE}"
    fi

    echo
    echo "[INFO] No se creó ninguna configuración parcial."
    echo "[INFO] Payload conservado:"
    echo "       ${REQUEST}"

    exit 2
    ;;

esac


# --------------------------------------------------------
# Leer configuración canónica
# --------------------------------------------------------

curl -ksSf \
  -H "${AUTH}" \
  "${INSTANA_URL}/api/events/settings/website-alert-configs" \
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
    ' "${CURRENT}" |
  head -1
)"

if [[ -z "${created_id}" ]]; then
  echo "[ERROR] POST aceptado, pero no encuentro la alerta."
  exit 3
fi

printf '%s\n' \
  "${created_id}" \
  > "${ID_FILE}"

curl -ksSf \
  -H "${AUTH}" \
  "${INSTANA_URL}/api/events/settings/website-alert-configs/${created_id}" \
  > "${CANONICAL}"


echo
echo "========================================================"
echo " BUSINESS SMART ALERT CREADA"
echo "========================================================"
echo
echo " Name : ${ALERT_NAME}"
echo " ID   : ${created_id}"
echo

echo "Configuración canónica"
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
echo " BUSINESS SMART ALERT : READY"
echo "--------------------------------------------------------"

#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/opt/instana-demo/instana-api"
STATE_DIR="${BASE_DIR}/state"
OUT_DIR="${STATE_DIR}/website-alerts"

source "${BASE_DIR}/00-load-instana-env.sh"

mkdir -p "${OUT_DIR}"

ALERT_ID="$(
  tr -d '\r\n' \
  < "${STATE_DIR}/website-alert-http503-id"
)"

ALERT_NAME="RETAIL - NOVA - HTTP 503"

AUTH="Authorization: apiToken ${INSTANA_TOKEN}"

EVENTS_FILE="${OUT_DIR}/http503-events.json"

#
# Terminamos la consulta 120 s atrás para evitar
# inconsistencia eventual del Events API.
#
TO_MS="$(( ($(date +%s) - 120) * 1000 ))"
WINDOW_MS=3600000

echo
echo "========================================================"
echo " INSTANA API | VERIFY WEBSITE SMART ALERT"
echo "========================================================"
echo
printf " Alert    : %s\n" "${ALERT_NAME}"
printf " Alert ID : %s\n" "${ALERT_ID}"
printf " Ventana  : 60 minutos\n"
echo

HTTP_CODE="$(
  curl -ksS \
    -o "${EVENTS_FILE}" \
    -w '%{http_code}' \
    -H "${AUTH}" \
    -H "Accept: application/json" \
    "${INSTANA_URL}/api/events?to=${TO_MS}&windowSize=${WINDOW_MS}" \
    || true
)"

if [[ "${HTTP_CODE}" != "200" ]]; then

  echo "[ERROR] Events API HTTP ${HTTP_CODE}"

  if [[ -s "${EVENTS_FILE}" ]]; then
    cat "${EVENTS_FILE}"
  fi

  exit 2
fi

echo "[OK] Events API consultada"
echo

echo "Estructura recibida"
echo "--------------------------------------------------------"

jq '
if type == "array" then
  {
    responseType: "array",
    eventCount: length
  }
else
  {
    responseType: type,
    keys: keys,
    eventCount:
      (
        (.items // .events // [])
        | length
      )
  }
end
' "${EVENTS_FILE}"

echo
echo "Eventos relacionados"
echo "--------------------------------------------------------"

jq \
  --arg alertId "${ALERT_ID}" \
  --arg alertName "${ALERT_NAME}" '
  (
    if type == "array"
    then .
    else (.items // .events // [])
    end
  )
  | map(
      select(
        (tostring | contains($alertId))
        or
        (tostring | contains($alertName))
        or
        (
          (tostring | ascii_downcase)
          | contains("http 503")
        )
        or
        (
          (tostring | ascii_downcase)
          | contains("status code 503")
        )
      )
    )
' "${EVENTS_FILE}" \
  > "${OUT_DIR}/http503-events-matched.json"

MATCHES="$(
  jq 'length' \
    "${OUT_DIR}/http503-events-matched.json"
)"

printf " Coincidencias : %s\n" "${MATCHES}"

if [[ "${MATCHES}" -gt 0 ]]; then

  echo
  echo "[OK] Evento asociado a la condición HTTP 503 encontrado."
  echo

  jq . \
    "${OUT_DIR}/http503-events-matched.json"

else

  echo
  echo "[WARN] No encontré coincidencia textual directa."
  echo
  echo "Se mostrarán los eventos recientes para identificar"
  echo "la estructura específica de esta versión de Instana."
  echo

  jq '
    (
      if type == "array"
      then .
      else (.items // .events // [])
      end
    )
    | .[:20]
  ' "${EVENTS_FILE}"

fi

echo
echo "Estado persistido"
echo "--------------------------------------------------------"
echo " ${EVENTS_FILE}"
echo " ${OUT_DIR}/http503-events-matched.json"

echo
echo "--------------------------------------------------------"
echo " HTTP 503 ALERT VERIFICATION : COMPLETE"
echo "--------------------------------------------------------"

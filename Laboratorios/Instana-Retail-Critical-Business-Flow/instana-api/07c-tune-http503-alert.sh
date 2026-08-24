#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/opt/instana-demo/instana-api"
STATE_DIR="${BASE_DIR}/state"
OUT_DIR="${STATE_DIR}/website-alerts"

source "${BASE_DIR}/00-load-instana-env.sh"

ALERT_ID="$(tr -d '\r\n' < "${STATE_DIR}/website-alert-http503-id")"

CURRENT="${OUT_DIR}/http503-before-tune.json"
REQUEST="${OUT_DIR}/http503-tune-request.json"
RESPONSE="${OUT_DIR}/http503-tune-response.json"
CANONICAL="${OUT_DIR}/http503-canonical.json"

AUTH="Authorization: apiToken ${INSTANA_TOKEN}"

echo
echo "========================================================"
echo " INSTANA API | TUNE WEBSITE SMART ALERT"
echo "========================================================"
echo
echo " Alert ID : ${ALERT_ID}"
echo " Objetivo : ventana de 60 segundos"
echo

curl -ksSf \
  -H "${AUTH}" \
  -H "Accept: application/json" \
  "${INSTANA_URL}/api/events/settings/website-alert-configs/${ALERT_ID}" \
  > "${CURRENT}"

echo "Configuración actual"
echo "--------------------------------------------------------"
jq '{
  name,
  granularity,
  timeThreshold,
  rule,
  threshold,
  rules
}' "${CURRENT}"

# Usamos el request que ya sabemos que Instana aceptó.
jq '
  .granularity = 60000
  | .timeThreshold.timeWindow = 60000
' "${OUT_DIR}/http503-request.json" \
  > "${REQUEST}"

echo
echo "Configuración propuesta"
echo "--------------------------------------------------------"
jq '{
  name,
  granularity,
  timeThreshold,
  rules
}' "${REQUEST}"

HTTP_CODE="$(
  curl -ksS \
    -o "${RESPONSE}" \
    -w '%{http_code}' \
    -X POST \
    -H "${AUTH}" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    --data @"${REQUEST}" \
    "${INSTANA_URL}/api/events/settings/website-alert-configs/${ALERT_ID}" \
    || true
)"

echo

case "${HTTP_CODE}" in

  200|201)

    echo "[OK] Instana aceptó ventana de 60 segundos."

    curl -ksSf \
      -H "${AUTH}" \
      "${INSTANA_URL}/api/events/settings/website-alert-configs/${ALERT_ID}" \
      > "${CANONICAL}"

    echo
    echo "Configuración efectiva"
    echo "--------------------------------------------------------"

    jq '{
      id,
      name,
      enabled,
      granularity,
      timeThreshold,
      rule,
      threshold
    }' "${CANONICAL}"
    ;;

  *)

    echo "[INFO] La versión actual no aceptó 60 segundos."
    echo "       HTTP ${HTTP_CODE}"
    echo
    echo "[OK] Se conserva la configuración existente."

    curl -ksSf \
      -H "${AUTH}" \
      "${INSTANA_URL}/api/events/settings/website-alert-configs/${ALERT_ID}" \
      > "${CANONICAL}"

    jq '{
      id,
      name,
      enabled,
      granularity,
      timeThreshold
    }' "${CANONICAL}"
    ;;

esac

echo
echo "--------------------------------------------------------"
echo " WEBSITE ALERT TUNING : COMPLETE"
echo "--------------------------------------------------------"

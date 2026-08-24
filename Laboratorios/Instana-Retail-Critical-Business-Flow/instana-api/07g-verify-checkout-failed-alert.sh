#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/opt/instana-demo/instana-api"
STATE_DIR="${BASE_DIR}/state"
OUT_DIR="${STATE_DIR}/website-alerts"

source "${BASE_DIR}/00-load-instana-env.sh"

mkdir -p "${OUT_DIR}"

ALERT_ID="$(
  tr -d '\r\n' \
  < "${STATE_DIR}/website-alert-checkout-failed-id"
)"

ALERT_NAME="RETAIL - NOVA - Checkout Failed"

AUTH="Authorization: apiToken ${INSTANA_TOKEN}"

EVENTS_FILE="${OUT_DIR}/checkout-failed-events.json"
MATCH_FILE="${OUT_DIR}/checkout-failed-events-matched.json"

echo
echo "========================================================"
echo " INSTANA API | VERIFY BUSINESS SMART ALERT"
echo "========================================================"
echo
echo " Alert    : ${ALERT_NAME}"
echo " Alert ID : ${ALERT_ID}"
echo
echo " Buscando Issue generado por Instana..."
echo

MAX_ATTEMPTS=12
SLEEP_SECONDS=15

for attempt in $(seq 1 "${MAX_ATTEMPTS}"); do

  TO_MS="$(( $(date +%s) * 1000 ))"
  WINDOW_MS=1800000

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
    echo "[WARN] Events API HTTP ${HTTP_CODE}"
    sleep "${SLEEP_SECONDS}"
    continue
  fi

  jq \
    --arg alertId "${ALERT_ID}" '
      (
        if type == "array"
        then .
        else (.items // .events // [])
        end
      )
      | map(
          select(
            .eventSpecificationId == $alertId
          )
        )
    ' "${EVENTS_FILE}" \
    > "${MATCH_FILE}"

  MATCHES="$(
    jq 'length' "${MATCH_FILE}"
  )"

  if [[ "${MATCHES}" -gt 0 ]]; then

    echo
    echo "[OK] Business Smart Alert disparada."
    echo
    echo "--------------------------------------------------------"

    jq '
      map({
        eventId: .eventId,
        start: .start,
        "end": .end,
        type: .type,
        state: .state,
        problem: .problem,
        detail: .detail,
        severity: .severity,
        entityName: .entityName,
        entityLabel: .entityLabel,
        metrics: .metrics,
        eventSpecificationId: .eventSpecificationId,
        websiteId: .websiteId
      })
    ' "${MATCH_FILE}"

    echo
    echo "--------------------------------------------------------"
    echo " BUSINESS SMART ALERT : VERIFIED"
    echo "--------------------------------------------------------"

    exit 0
  fi

  echo "[ESPERA] Intento ${attempt}/${MAX_ATTEMPTS} - Issue aún no visible"

  if [[ "${attempt}" -lt "${MAX_ATTEMPTS}" ]]; then
    sleep "${SLEEP_SECONDS}"
  fi

done

echo
echo "[WARN] No apareció el Issue dentro de la ventana de validación."
echo
echo "La señal puede revisarse en:"
echo " ${EVENTS_FILE}"

echo
echo "--------------------------------------------------------"
echo " BUSINESS SMART ALERT : NOT YET OBSERVED"
echo "--------------------------------------------------------"

exit 1

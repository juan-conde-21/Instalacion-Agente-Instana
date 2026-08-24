#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/opt/instana-demo/instana-api"
STATE_DIR="${BASE_DIR}/state"

source "${BASE_DIR}/00-load-instana-env.sh"

HTTP_ID="$(
  tr -d '\r\n' \
  < "${STATE_DIR}/website-alert-http503-id"
)"

BUSINESS_ID="$(
  tr -d '\r\n' \
  < "${STATE_DIR}/website-alert-checkout-failed-id"
)"

AUTH="Authorization: apiToken ${INSTANA_TOKEN}"

MAX_POLLS=20
SLEEP_SECONDS=15
WINDOW_MS=7200000

echo
echo "========================================================"
echo " INSTANA | WAIT FOR SMART ALERT RECOVERY"
echo "========================================================"
echo
echo " HTTP 503 Alert : ${HTTP_ID}"
echo " Checkout Alert : ${BUSINESS_ID}"
echo
echo " Instana evalúa las alertas."
echo " Este script solamente consulta su estado cada 15s."
echo

for poll in $(seq 1 "${MAX_POLLS}"); do

  TO_MS="$(( $(date +%s) * 1000 ))"

  EVENTS="$(
    curl -ksSf \
      -H "${AUTH}" \
      -H "Accept: application/json" \
      "${INSTANA_URL}/api/events?to=${TO_MS}&windowSize=${WINDOW_MS}"
  )"

  HTTP_STATE="$(
    jq -r \
      --arg id "${HTTP_ID}" '
        [
          .[]
          | select(.eventSpecificationId == $id)
        ]
        | sort_by(.start)
        | reverse
        | .[0].state // "NOT_FOUND"
      ' <<< "${EVENTS}"
  )"

  BUSINESS_STATE="$(
    jq -r \
      --arg id "${BUSINESS_ID}" '
        [
          .[]
          | select(.eventSpecificationId == $id)
        ]
        | sort_by(.start)
        | reverse
        | .[0].state // "NOT_FOUND"
      ' <<< "${EVENTS}"
  )"

  HTTP_END="$(
    jq -r \
      --arg id "${HTTP_ID}" '
        [
          .[]
          | select(.eventSpecificationId == $id)
        ]
        | sort_by(.start)
        | reverse
        | .[0].end // "-"
      ' <<< "${EVENTS}"
  )"

  BUSINESS_END="$(
    jq -r \
      --arg id "${BUSINESS_ID}" '
        [
          .[]
          | select(.eventSpecificationId == $id)
        ]
        | sort_by(.start)
        | reverse
        | .[0].end // "-"
      ' <<< "${EVENTS}"
  )"

  ELAPSED="$(( (poll - 1) * SLEEP_SECONDS ))"

  printf \
    "[POLL %02d/%02d | %3ds] HTTP503=%-6s CheckoutFailed=%-6s\n" \
    "${poll}" \
    "${MAX_POLLS}" \
    "${ELAPSED}" \
    "${HTTP_STATE}" \
    "${BUSINESS_STATE}"

  printf \
    "                     end=%s / %s\n" \
    "${HTTP_END}" \
    "${BUSINESS_END}"

  if [[ "${HTTP_STATE}" == "closed" &&
        "${BUSINESS_STATE}" == "closed" ]]; then

    echo
    echo "========================================================"
    echo " RECUPERACIÓN COMPLETA"
    echo "========================================================"
    echo
    echo "[OK] HTTP 503        : closed"
    echo "[OK] Checkout Failed : closed"
    echo
    echo "[OK] Instana cerró ambas alertas automáticamente."
    exit 0
  fi

  if [[ "${poll}" -lt "${MAX_POLLS}" ]]; then
    sleep "${SLEEP_SECONDS}"
  fi

done

echo
echo "[WARN] Tras $((MAX_POLLS * SLEEP_SECONDS))s"
echo "       alguna Smart Alert continúa OPEN."
echo
echo "Ejecute:"
echo " ${BASE_DIR}/07h-audit-alert-lifecycle.sh"

exit 2

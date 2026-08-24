#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/opt/instana-demo/instana-api"
STATE_DIR="${BASE_DIR}/state"
OUT_DIR="${STATE_DIR}/website-alerts"

source "${BASE_DIR}/00-load-instana-env.sh"

mkdir -p "${OUT_DIR}"

HTTP_ID="$(
  tr -d '\r\n' \
  < "${STATE_DIR}/website-alert-http503-id"
)"

BUSINESS_ID="$(
  tr -d '\r\n' \
  < "${STATE_DIR}/website-alert-checkout-failed-id"
)"

AUTH="Authorization: apiToken ${INSTANA_TOKEN}"

EVENTS="${OUT_DIR}/alert-lifecycle-events.json"

TO_MS="$(( $(date +%s) * 1000 ))"
WINDOW_MS=7200000

echo
echo "========================================================"
echo " INSTANA | SMART ALERT LIFECYCLE"
echo "========================================================"
echo

curl -ksSf \
  -H "${AUTH}" \
  -H "Accept: application/json" \
  "${INSTANA_URL}/api/events?to=${TO_MS}&windowSize=${WINDOW_MS}" \
  > "${EVENTS}"

show_alert() {

  local id="$1"
  local name="$2"

  echo "--------------------------------------------------------"
  echo " ${name}"
  echo "--------------------------------------------------------"

  jq \
    --arg id "${id}" '
      [
        .[]
        | select(
            .eventSpecificationId == $id
          )
      ]
      | sort_by(.start)
      | reverse
      | if length == 0 then
          {
            found: false
          }
        else
          .[0]
          | {
              found: true,
              eventId: .eventId,
              state: .state,
              start: .start,
              "end": .end,
              problem: .problem,
              severity: .severity,
              entityLabel: .entityLabel,
              eventSpecificationId:
                .eventSpecificationId
            }
        end
    ' "${EVENTS}"

  echo
}

show_alert \
  "${HTTP_ID}" \
  "RETAIL - NOVA - HTTP 503"

show_alert \
  "${BUSINESS_ID}" \
  "RETAIL - NOVA - Checkout Failed"


echo "========================================================"
echo " RESUMEN"
echo "========================================================"

HTTP_STATE="$(
  jq -r \
    --arg id "${HTTP_ID}" '
      [
        .[]
        | select(
            .eventSpecificationId == $id
          )
      ]
      | sort_by(.start)
      | reverse
      | .[0].state // "NOT_FOUND"
    ' "${EVENTS}"
)"

BUSINESS_STATE="$(
  jq -r \
    --arg id "${BUSINESS_ID}" '
      [
        .[]
        | select(
            .eventSpecificationId == $id
          )
      ]
      | sort_by(.start)
      | reverse
      | .[0].state // "NOT_FOUND"
    ' "${EVENTS}"
)"

printf " HTTP 503        : %s\n" "${HTTP_STATE}"
printf " Checkout Failed : %s\n" "${BUSINESS_STATE}"

echo

if [[ "${HTTP_STATE}" == "closed" &&
      "${BUSINESS_STATE}" == "closed" ]]; then

  echo "[OK] Ambas Smart Alerts están recuperadas."

elif [[ "${HTTP_STATE}" == "open" ||
        "${BUSINESS_STATE}" == "open" ]]; then

  echo "[INFO] Existe al menos un Issue todavía OPEN."
  echo "       Instana continúa evaluando la recuperación."

else

  echo "[INFO] Revisar estados mostrados."

fi

echo
echo "--------------------------------------------------------"
echo " ALERT LIFECYCLE AUDIT : COMPLETE"
echo "--------------------------------------------------------"

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(
  cd "$(dirname "${BASH_SOURCE[0]}")"   && pwd
)"

BASE_DIR="${SCRIPT_DIR}"
API_DIR="${SCRIPT_DIR}"
DEMO_DIR="/opt/instana-demo/demo"
STATE_DIR="${API_DIR}/state"

source "${API_DIR}/00-load-instana-env.sh"

AUTH="Authorization: apiToken ${INSTANA_TOKEN}"

source "${SCRIPT_DIR}/00-load-runtime-ids.sh"

BROWSER_ID="$(
  tr -d '\r\n' \
  < "${STATE_DIR}/synthetic-nova-browser-journey-id"
)"

HTTP_ALERT_ID="$(
  tr -d '\r\n' \
  < "${STATE_DIR}/website-alert-http503-id"
)"

BUSINESS_ALERT_ID="$(
  tr -d '\r\n' \
  < "${STATE_DIR}/website-alert-checkout-failed-id"
)"

TO_MS="$(( $(date +%s) * 1000 ))"
WINDOW_MS=3600000

TMP="/tmp/instana-final-audit"
mkdir -p "${TMP}"

PASS=0
WARN=0


ok() {
  printf " [OK]     %-25s %s\n" "$1" "$2"
  PASS=$((PASS + 1))
}


warn() {
  printf " [WARN]   %-25s %s\n" "$1" "$2"
  WARN=$((WARN + 1))
}


echo
echo "========================================================"
echo " INSTANA | FINAL LAB AUDIT"
echo "========================================================"
echo


# ========================================================
# 1. NEGOCIO
# ========================================================

echo "Negocio"
echo "--------------------------------------------------------"

HEALTH="$(
  curl -fsS \
    http://192.168.252.33:18083/health
)"

if [[ "$(jq -r '.status' <<< "${HEALTH}")" == "UP" ]]; then
  ok "RETAIL" "UP"
else
  warn "RETAIL" "No saludable"
fi


BUSINESS_CODE="$(
  curl -sS \
    -o "${TMP}/business.json" \
    -w '%{http_code}' \
    http://192.168.252.33:18083/api/operation/P00001
)"

if [[ "${BUSINESS_CODE}" == "200" ]]; then
  ok "Negocio" "HTTP 200"
else
  warn "Negocio" "HTTP ${BUSINESS_CODE}"
fi


# ========================================================
# 2. APPLICATION
# ========================================================

echo
echo "Application Perspective"
echo "--------------------------------------------------------"

curl -ksSf \
  -H "${AUTH}" \
  "${INSTANA_URL}/api/application-monitoring/applications?to=${TO_MS}&windowSize=${WINDOW_MS}" \
  > "${TMP}/applications.json"

APP_LABEL="$(
  jq -r \
    --arg id "${APP_ID}" '
      .items[]
      | select(.id == $id)
      | .label
    ' "${TMP}/applications.json"
)"

if [[ "${APP_LABEL}" == "RETAIL - Critical Promotions Flow" ]]; then
  ok "Application" "${APP_LABEL}"
else
  warn "Application" "No encontrada"
fi


curl -ksSf \
  -H "${AUTH}" \
  "${INSTANA_URL}/api/application-monitoring/applications;id=${APP_ID}/services?to=${TO_MS}&windowSize=${WINDOW_MS}" \
  > "${TMP}/services.json"

SERVICE_COUNT="$(
  jq '
    (.items // [])
    | length
  ' "${TMP}/services.json"
)"

if [[ "${SERVICE_COUNT}" -ge 2 ]]; then
  ok "Services" "${SERVICE_COUNT} detectados"
else
  warn "Services" "${SERVICE_COUNT} detectados"
fi


# ========================================================
# 3. DEPENDENCIES
# ========================================================

echo
echo "Dependencies"
echo "--------------------------------------------------------"

curl -ksSf \
  -H "${AUTH}" \
  "${INSTANA_URL}/api/application-monitoring/topology/services?to=${TO_MS}&windowSize=${WINDOW_MS}&applicationId=${APP_ID}&applicationBoundaryScope=ALL" \
  > "${TMP}/topology.json"

RETAIL_CENTRAL_CALLS="$(
  jq -r \
    --arg from "${RETAIL_ID}" \
    --arg to "${CENTRAL_ID}" '
      [
        (.connections // [])[]
        | select(
            .from == $from
            and
            .to == $to
          )
      ]
      | .[0].calls // 0
    ' "${TMP}/topology.json"
)"

if [[ "${RETAIL_CENTRAL_CALLS}" -gt 0 ]]; then
  ok \
    "RETAIL -> CENTRAL" \
    "${RETAIL_CENTRAL_CALLS} calls"
else
  warn \
    "RETAIL -> CENTRAL" \
    "Sin llamadas en ventana"
fi


# ========================================================
# 4. WEBSITE
# ========================================================

echo
echo "Website / EUM"
echo "--------------------------------------------------------"

curl -ksSf \
  -H "${AUTH}" \
  "${INSTANA_URL}/api/website-monitoring/config" \
  > "${TMP}/websites.json"

WEBSITE_NAME="$(
  jq -r \
    --arg id "${WEBSITE_ID}" '
      .[]
      | select(.id == $id)
      | .name
    ' "${TMP}/websites.json"
)"

if [[ "${WEBSITE_NAME}" == "RETAIL - NOVA Market" ]]; then
  ok "Website" "${WEBSITE_NAME}"
else
  warn "Website" "No encontrado"
fi


# ========================================================
# 5. SYNTHETICS
# ========================================================

echo
echo "Synthetic Monitoring"
echo "--------------------------------------------------------"

curl -ksSf \
  -H "${AUTH}" \
  "${INSTANA_URL}/api/synthetics/settings/locations" \
  > "${TMP}/locations.json"

POP_STATUS="$(
  jq -r '
    .[]
    | select(
        .label ==
        "instana-critical-demo-pop"
      )
    | .status
  ' "${TMP}/locations.json"
)"

if [[ "${POP_STATUS}" == "Online" ]]; then
  ok "Private PoP" "Online"
else
  warn "Private PoP" "${POP_STATUS:-NOT_FOUND}"
fi


curl -ksSf \
  -H "${AUTH}" \
  "${INSTANA_URL}/api/synthetics/settings/tests/${BROWSER_ID}" \
  > "${TMP}/browser.json"

BROWSER_ACTIVE="$(
  jq -r '.active' "${TMP}/browser.json"
)"

BROWSER_TYPE="$(
  jq -r \
    '.configuration.syntheticType' \
    "${TMP}/browser.json"
)"

if [[ "${BROWSER_ACTIVE}" == "true" &&
      "${BROWSER_TYPE}" == "BrowserScript" ]]; then

  ok \
    "Customer Journey" \
    "BrowserScript activo"

else

  warn \
    "Customer Journey" \
    "Revisar configuración"

fi


APP_ASSOC="$(
  jq \
    --arg id "${APP_ID}" '
      (.applications // [])
      | index($id) != null
    ' "${TMP}/browser.json"
)"

WEB_ASSOC="$(
  jq \
    --arg id "${WEBSITE_ID}" '
      (.websites // [])
      | index($id) != null
    ' "${TMP}/browser.json"
)"

if [[ "${APP_ASSOC}" == "true" ]]; then
  ok "Synthetic -> App" "Asociado"
else
  warn "Synthetic -> App" "No asociado"
fi

if [[ "${WEB_ASSOC}" == "true" ]]; then
  ok "Synthetic -> Website" "Asociado"
else
  warn "Synthetic -> Website" "No asociado"
fi


# ========================================================
# 6. SMART ALERTS
# ========================================================

echo
echo "Smart Alerts"
echo "--------------------------------------------------------"

EVENTS="$(
  curl -ksSf \
    -H "${AUTH}" \
    "${INSTANA_URL}/api/events?to=${TO_MS}&windowSize=7200000"
)"

HTTP_STATE="$(
  jq -r \
    --arg id "${HTTP_ALERT_ID}" '
      [
        .[]
        | select(
            .eventSpecificationId == $id
          )
      ]
      | sort_by(.start)
      | reverse
      | .[0].state // "NOT_FOUND"
    ' <<< "${EVENTS}"
)"

BUSINESS_STATE="$(
  jq -r \
    --arg id "${BUSINESS_ALERT_ID}" '
      [
        .[]
        | select(
            .eventSpecificationId == $id
          )
      ]
      | sort_by(.start)
      | reverse
      | .[0].state // "NOT_FOUND"
    ' <<< "${EVENTS}"
)"

if [[ "${HTTP_STATE}" == "closed" ]]; then
  ok "HTTP 503 Alert" "closed"
else
  warn "HTTP 503 Alert" "${HTTP_STATE}"
fi

if [[ "${BUSINESS_STATE}" == "closed" ]]; then
  ok "Checkout Failed Alert" "closed"
else
  warn "Checkout Failed Alert" "${BUSINESS_STATE}"
fi


# ========================================================
# RESULTADO
# ========================================================

echo
echo "========================================================"
echo " RESULTADO FINAL"
echo "========================================================"
echo
printf " Checks OK       : %s\n" "${PASS}"
printf " Advertencias    : %s\n" "${WARN}"
echo

if [[ "${WARN}" -eq 0 ]]; then

  echo " LAB STATUS : READY FOR DEMO"

else

  echo " LAB STATUS : READY WITH WARNINGS"

fi

echo
echo "--------------------------------------------------------"
echo " Flujo demostrado"
echo "--------------------------------------------------------"
echo " HEALTHY"
echo "   -> Synthetic PASS"
echo "   -> fault"
echo "   -> negocio 503"
echo "   -> Browser Synthetic FAIL"
echo "   -> EUM Checkout Failed"
echo "   -> Smart Alerts OPEN"
echo "   -> recover"
echo "   -> Synthetic PASS"
echo "   -> Smart Alerts CLOSED"
echo "   -> Dependencies RETAIL -> CENTRAL"
echo

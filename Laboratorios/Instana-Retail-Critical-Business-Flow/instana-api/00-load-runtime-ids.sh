#!/usr/bin/env bash

API_DIR="$(
  cd "$(dirname "${BASH_SOURCE[0]}")" \
  && pwd
)"

STATE_DIR="${API_DIR}/state"

if ! source "${API_DIR}/00-load-instana-env.sh"; then
  echo "[ERROR] No fue posible cargar la configuración de Instana."
  return 1 2>/dev/null || exit 1
fi

mkdir -p "${STATE_DIR}"

AUTH="Authorization: apiToken ${INSTANA_TOKEN}"

APPLICATION_LABEL="RETAIL - Critical Promotions Flow"
WEBSITE_LABEL="RETAIL - NOVA Market"
RETAIL_LABEL="retail-app"
CENTRAL_LABEL="central-service"

TO_MS="$(( $(date +%s) * 1000 ))"
WINDOW_MS=3600000


# ========================================================
# APPLICATION
# ========================================================

APPS_JSON="$(
  curl -ksSf \
    -H "${AUTH}" \
    -H "Accept: application/json" \
    "${INSTANA_URL}/api/application-monitoring/applications?to=${TO_MS}&windowSize=${WINDOW_MS}"
)"

APP_ID="$(
  jq -r \
    --arg appLabel "${APPLICATION_LABEL}" '
      (
        if type == "array"
        then .
        else (.items // [])
        end
      )
      | .[]
      | select(.label == $appLabel)
      | .id
    ' <<< "${APPS_JSON}" \
  | sed -n '1p'
)"

if [[ -z "${APP_ID}" || "${APP_ID}" == "null" ]]; then
  echo "[ERROR] Application no encontrada: ${APPLICATION_LABEL}"
  return 1 2>/dev/null || exit 1
fi

printf '%s\n' "${APP_ID}" \
  > "${STATE_DIR}/application-id"


# ========================================================
# WEBSITE
# ========================================================

WEBSITES_JSON="$(
  curl -ksSf \
    -H "${AUTH}" \
    -H "Accept: application/json" \
    "${INSTANA_URL}/api/website-monitoring/config"
)"

WEBSITE_ID="$(
  jq -r \
    --arg websiteLabel "${WEBSITE_LABEL}" '
      (
        if type == "array"
        then .
        else (.items // .configs // [])
        end
      )
      | .[]
      | select(
          (.name // .label // "") == $websiteLabel
        )
      | .id
    ' <<< "${WEBSITES_JSON}" \
  | sed -n '1p'
)"

if [[ -z "${WEBSITE_ID}" || "${WEBSITE_ID}" == "null" ]]; then
  echo "[ERROR] Website no encontrado: ${WEBSITE_LABEL}"
  return 1 2>/dev/null || exit 1
fi

printf '%s\n' "${WEBSITE_ID}" \
  > "${STATE_DIR}/website-id"


# ========================================================
# SERVICES
# ========================================================

SERVICES_JSON="$(
  curl -ksSf \
    -H "${AUTH}" \
    -H "Accept: application/json" \
    "${INSTANA_URL}/api/application-monitoring/applications;id=${APP_ID}/services?to=${TO_MS}&windowSize=${WINDOW_MS}"
)"

RETAIL_ID="$(
  jq -r \
    --arg serviceLabel "${RETAIL_LABEL}" '
      (
        if type == "array"
        then .
        else (.items // [])
        end
      )
      | .[]
      | select(
          (.label // .name // "") == $serviceLabel
        )
      | .id
    ' <<< "${SERVICES_JSON}" \
  | sed -n '1p'
)"

CENTRAL_ID="$(
  jq -r \
    --arg serviceLabel "${CENTRAL_LABEL}" '
      (
        if type == "array"
        then .
        else (.items // [])
        end
      )
      | .[]
      | select(
          (.label // .name // "") == $serviceLabel
        )
      | .id
    ' <<< "${SERVICES_JSON}" \
  | sed -n '1p'
)"

if [[ -z "${RETAIL_ID}" || "${RETAIL_ID}" == "null" ]]; then
  echo "[ERROR] Service no encontrado: ${RETAIL_LABEL}"
  return 1 2>/dev/null || exit 1
fi

if [[ -z "${CENTRAL_ID}" || "${CENTRAL_ID}" == "null" ]]; then
  echo "[ERROR] Service no encontrado: ${CENTRAL_LABEL}"
  return 1 2>/dev/null || exit 1
fi

printf '%s\n' "${RETAIL_ID}" \
  > "${STATE_DIR}/retail-service-id"

printf '%s\n' "${CENTRAL_ID}" \
  > "${STATE_DIR}/central-service-id"


export \
  APP_ID \
  WEBSITE_ID \
  RETAIL_ID \
  CENTRAL_ID

#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/opt/instana-demo/instana-api"
STATE_DIR="${BASE_DIR}/state"
OUT_DIR="${STATE_DIR}/synthetic/browser-journey"

source "${BASE_DIR}/00-load-instana-env.sh"

TEST_ID="$(
  tr -d '\r\n' \
  < "${STATE_DIR}/synthetic-nova-browser-journey-id"
)"

SCRIPT_FILE="${OUT_DIR}/nova-customer-journey.js"

BEFORE="${OUT_DIR}/before-basic-update.json"
REQUEST="${OUT_DIR}/basic-update-request.json"
RESPONSE="${OUT_DIR}/basic-update-response.json"
AFTER="${OUT_DIR}/canonical.json"

AUTH="Authorization: apiToken ${INSTANA_TOKEN}"

[[ -f "${SCRIPT_FILE}" ]] || {
  echo "[ERROR] No encuentro ${SCRIPT_FILE}"
  exit 1
}

echo
echo "========================================================"
echo " INSTANA API | UPDATE NOVA BROWSER JOURNEY"
echo "========================================================"
echo
echo " Test ID : ${TEST_ID}"
echo

#
# Obtener configuración actual completa.
#
curl -ksSf \
  -H "${AUTH}" \
  -H "Accept: application/json" \
  "${INSTANA_URL}/api/synthetics/settings/tests/${TEST_ID}" \
  > "${BEFORE}"


echo "Configuración actual"
echo "--------------------------------------------------------"

jq '{
  id: .id,
  label: .label,
  active: .active,
  frequency: .testFrequency,
  locations: .locations,
  applications: .applications,
  websites: .websites,
  syntheticType: .configuration.syntheticType,
  scriptType: .configuration.scriptType,
  browser: .configuration.browser
}' "${BEFORE}"


#
# Mantener toda la configuración actual del BrowserScript
# y sustituir únicamente script + scriptType.
#
jq \
  --rawfile script "${SCRIPT_FILE}" '
{
  configuration:
    (
      .configuration
      + {
          script: $script,
          scriptType: "Basic"
        }
    )
}
' "${BEFORE}" \
  > "${REQUEST}"


echo
echo "Actualización"
echo "--------------------------------------------------------"

jq '
  .configuration.script =
    "<nova-customer-journey.js>"
' "${REQUEST}"


HTTP_CODE="$(
  curl -ksS \
    -o "${RESPONSE}" \
    -w '%{http_code}' \
    -X PATCH \
    -H "${AUTH}" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    --data @"${REQUEST}" \
    "${INSTANA_URL}/api/synthetics/settings/tests/${TEST_ID}" \
    || true
)"


case "${HTTP_CODE}" in

  200|204)
    echo
    echo "[OK] Script actualizado (HTTP ${HTTP_CODE})"
    ;;

  *)
    echo
    echo "[ERROR] PATCH HTTP ${HTTP_CODE}"

    if [[ -s "${RESPONSE}" ]]; then
      jq . "${RESPONSE}" 2>/dev/null ||
        cat "${RESPONSE}"
    fi

    exit 2
    ;;

esac


#
# Leer configuración efectiva.
#
curl -ksSf \
  -H "${AUTH}" \
  -H "Accept: application/json" \
  "${INSTANA_URL}/api/synthetics/settings/tests/${TEST_ID}" \
  > "${AFTER}"


echo
echo "Configuración efectiva"
echo "--------------------------------------------------------"

jq '{
  id: .id,
  label: .label,
  active: .active,
  testFrequency: .testFrequency,
  locations: .locations,
  locationLabels: .locationLabels,
  applications: .applications,
  applicationLabels: .applicationLabels,
  websites: .websites,
  websiteLabels: .websiteLabels,
  configuration: {
    syntheticType:
      .configuration.syntheticType,
    scriptType:
      .configuration.scriptType,
    browser:
      .configuration.browser,
    recordVideo:
      .configuration.recordVideo,
    markSyntheticCall:
      .configuration.markSyntheticCall
  }
}' "${AFTER}"


echo
echo "--------------------------------------------------------"
echo " BROWSER SCRIPT UPDATE : READY"
echo "--------------------------------------------------------"

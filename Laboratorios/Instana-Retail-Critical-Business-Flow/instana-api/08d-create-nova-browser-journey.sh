#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/opt/instana-demo/instana-api"
STATE_DIR="${BASE_DIR}/state"

SYNTH_DIR="${STATE_DIR}/synthetic"
OUT_DIR="${SYNTH_DIR}/browser-journey"

source "${BASE_DIR}/00-load-instana-env.sh"

mkdir -p "${OUT_DIR}"

AUTH="Authorization: apiToken ${INSTANA_TOKEN}"

TEST_LABEL="RETAIL - NOVA - Customer Journey"

SCRIPT_FILE="${OUT_DIR}/nova-customer-journey.js"

REQUEST="${OUT_DIR}/create-request.json"
RESPONSE="${OUT_DIR}/create-response.json"
CANONICAL="${OUT_DIR}/canonical.json"
TESTS="${OUT_DIR}/tests.json"

ID_FILE="${STATE_DIR}/synthetic-nova-browser-journey-id"


# --------------------------------------------------------
# Resolver IDs reales
# --------------------------------------------------------

LOCATION_ID="$(
  jq -r '
    .[]
    | select(
        .label ==
        "instana-critical-demo-pop"
      )
    | .id
  ' "${SYNTH_DIR}/locations.json" |
  head -1
)"

APPLICATION_ID="$(
  jq -r '
    .items[]
    | select(
        .label ==
        "RETAIL - Critical Promotions Flow"
      )
    | .id
  ' "${SYNTH_DIR}/applications.json" |
  head -1
)"

WEBSITE_ID="$(
  jq -r '
    .[]
    | select(
        .name ==
        "RETAIL - NOVA Market"
      )
    | .id
  ' "${SYNTH_DIR}/websites.json" |
  head -1
)"


for value in \
  LOCATION_ID \
  APPLICATION_ID \
  WEBSITE_ID
do

  resolved="${!value:-}"

  if [[ -z "${resolved}" ||
        "${resolved}" == "null" ]]; then

    echo "[ERROR] No pude resolver ${value}"
    exit 1
  fi

done


[[ -f "${SCRIPT_FILE}" ]] || {
  echo "[ERROR] Falta ${SCRIPT_FILE}"
  exit 1
}


echo
echo "========================================================"
echo " INSTANA API | CREATE BROWSER JOURNEY"
echo "========================================================"
echo
echo " Test        : ${TEST_LABEL}"
echo " Location    : ${LOCATION_ID}"
echo " Application : ${APPLICATION_ID}"
echo " Website     : ${WEBSITE_ID}"
echo


# --------------------------------------------------------
# Idempotencia
# --------------------------------------------------------

curl -ksSf \
  -H "${AUTH}" \
  -H "Accept: application/json" \
  "${INSTANA_URL}/api/synthetics/settings/tests" \
  > "${TESTS}"


EXISTING_ID="$(
  jq -r \
    --arg testLabel "${TEST_LABEL}" '
      .[]
      | select(
          .label == $testLabel
        )
      | .id
    ' "${TESTS}" |
  head -1
)"


if [[ -n "${EXISTING_ID}" ]]; then

  echo "[OK] Browser Journey ya existe"
  echo "     ID: ${EXISTING_ID}"

  printf '%s\n' \
    "${EXISTING_ID}" \
    > "${ID_FILE}"

  curl -ksSf \
    -H "${AUTH}" \
    "${INSTANA_URL}/api/synthetics/settings/tests/${EXISTING_ID}" \
    > "${CANONICAL}"

  jq '{
    id: .id,
    label: .label,
    active: .active,
    testFrequency: .testFrequency,
    locations: .locations,
    applications: .applications,
    websites: .websites,
    configuration: {
      syntheticType:
        .configuration.syntheticType,
      browser:
        .configuration.browser,
      recordVideo:
        .configuration.recordVideo,
      markSyntheticCall:
        .configuration.markSyntheticCall
    }
  }' "${CANONICAL}"

  echo
  echo "--------------------------------------------------------"
  echo " BROWSER JOURNEY : READY"
  echo "--------------------------------------------------------"

  exit 0
fi


# --------------------------------------------------------
# Payload
# --------------------------------------------------------

jq -n \
  --rawfile script "${SCRIPT_FILE}" \
  --arg location "${LOCATION_ID}" \
  --arg application "${APPLICATION_ID}" \
  --arg website "${WEBSITE_ID}" '
{
  label:
    "RETAIL - NOVA - Customer Journey",

  description:
    "Valida el recorrido real de NOVA: login de Valeria, selección de producto y checkout.",

  active: true,

  testFrequency: 1,

  playbackMode:
    "Simultaneous",

  locations: [
    $location
  ],

  applications: [
    $application
  ],

  websites: [
    $website
  ],

  configuration: {

    syntheticType:
      "BrowserScript",

    script:
      $script,

    scriptType:
      "Basic",

    browser:
      "chrome",

    recordVideo:
      false,

    markSyntheticCall:
      true,

    retries:
      0,

    retryInterval:
      1,

    timeout:
      "2m"
  },

  customProperties: {
    application:
      "nova-market",

    businessFlow:
      "retail-critical-flow",

    journey:
      "checkout",

    profile:
      "valeria"
  }
}
' > "${REQUEST}"


echo "Configuración solicitada"
echo "--------------------------------------------------------"

jq '
  .configuration.script =
    "<nova-customer-journey.js>"
' "${REQUEST}"


echo
echo "[INFO] Creando Browser Journey..."


HTTP_CODE="$(
  curl -ksS \
    -o "${RESPONSE}" \
    -w '%{http_code}' \
    -X POST \
    -H "${AUTH}" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    --data @"${REQUEST}" \
    "${INSTANA_URL}/api/synthetics/settings/tests" \
    || true
)"


case "${HTTP_CODE}" in

  200|201)

    echo "[OK] Instana aceptó Browser Journey (HTTP ${HTTP_CODE})"
    ;;

  *)

    echo
    echo "[ERROR] Instana rechazó Browser Journey"
    echo "        HTTP ${HTTP_CODE}"
    echo

    if [[ -s "${RESPONSE}" ]]; then
      jq . "${RESPONSE}" 2>/dev/null ||
        cat "${RESPONSE}"
    fi

    echo
    echo "Payload:"
    echo " ${REQUEST}"

    exit 2
    ;;

esac


# --------------------------------------------------------
# Leer de vuelta
# --------------------------------------------------------

curl -ksSf \
  -H "${AUTH}" \
  "${INSTANA_URL}/api/synthetics/settings/tests" \
  > "${TESTS}"


CREATED_ID="$(
  jq -r \
    --arg testLabel "${TEST_LABEL}" '
      .[]
      | select(
          .label == $testLabel
        )
      | .id
    ' "${TESTS}" |
  head -1
)"


if [[ -z "${CREATED_ID}" ]]; then

  echo "[ERROR] POST aceptado pero no encuentro el test."
  exit 3
fi


printf '%s\n' \
  "${CREATED_ID}" \
  > "${ID_FILE}"


curl -ksSf \
  -H "${AUTH}" \
  "${INSTANA_URL}/api/synthetics/settings/tests/${CREATED_ID}" \
  > "${CANONICAL}"


echo
echo "========================================================"
echo " BROWSER JOURNEY CREADO"
echo "========================================================"
echo
echo " Name : ${TEST_LABEL}"
echo " ID   : ${CREATED_ID}"
echo


jq '{
  id: .id,
  label: .label,
  active: .active,
  testFrequency: .testFrequency,
  playbackMode: .playbackMode,
  locations: .locations,
  locationLabels: .locationLabels,
  applications: .applications,
  applicationLabels: .applicationLabels,
  websites: .websites,
  websiteLabels: .websiteLabels,
  configuration: {
    syntheticType:
      .configuration.syntheticType,
    browser:
      .configuration.browser,
    recordVideo:
      .configuration.recordVideo,
    markSyntheticCall:
      .configuration.markSyntheticCall,
    timeout:
      .configuration.timeout
  }
}' "${CANONICAL}"


echo
echo "Estado persistido"
echo "--------------------------------------------------------"
echo " ${ID_FILE}"
echo " ${REQUEST}"
echo " ${RESPONSE}"
echo " ${CANONICAL}"

echo
echo "--------------------------------------------------------"
echo " BROWSER JOURNEY : READY"
echo "--------------------------------------------------------"

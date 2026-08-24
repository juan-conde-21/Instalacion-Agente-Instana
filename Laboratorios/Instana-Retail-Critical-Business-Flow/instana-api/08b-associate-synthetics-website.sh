#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(
  cd "$(dirname "${BASH_SOURCE[0]}")"   && pwd
)"

BASE_DIR="${SCRIPT_DIR}"
API_DIR="${SCRIPT_DIR}"
STATE_DIR="${BASE_DIR}/state"
OUT_DIR="${STATE_DIR}/synthetic"

source "${BASE_DIR}/00-load-instana-env.sh"

mkdir -p "${OUT_DIR}/backup"

AUTH="Authorization: apiToken ${INSTANA_TOKEN}"

source "${SCRIPT_DIR}/00-load-runtime-ids.sh"
APPLICATION_ID="${APP_ID}"

BUSINESS_ID_FILE="${STATE_DIR}/synthetic-business-id"
TECHNICAL_ID_FILE="${STATE_DIR}/synthetic-technical-id"

for required in "${BUSINESS_ID_FILE}" "${TECHNICAL_ID_FILE}"; do
  if [[ ! -s "${required}" ]]; then
    echo "[ERROR] Falta estado Synthetic: ${required}"
    echo "        Ejecute primero 02-sync-synthetics.sh"
    exit 1
  fi
done

BUSINESS_TEST_ID="$(tr -d '\r\n' < "${BUSINESS_ID_FILE}")"
TECHNICAL_TEST_ID="$(tr -d '\r\n' < "${TECHNICAL_ID_FILE}")"

TEST_IDS=(
  "${BUSINESS_TEST_ID}"
  "${TECHNICAL_TEST_ID}"
)

echo
echo "========================================================"
echo " INSTANA API | SYNTHETIC ASSOCIATIONS"
echo "========================================================"
echo
echo " Application : ${APPLICATION_ID}"
echo " Website     : ${WEBSITE_ID}"
echo

for TEST_ID in "${TEST_IDS[@]}"; do

  BEFORE="${OUT_DIR}/backup/${TEST_ID}-before.json"
  PATCH_FILE="${OUT_DIR}/${TEST_ID}-association-request.json"
  RESPONSE="${OUT_DIR}/${TEST_ID}-association-response.json"
  AFTER="${OUT_DIR}/${TEST_ID}-after.json"

  echo "--------------------------------------------------------"
  echo " Test : ${TEST_ID}"
  echo "--------------------------------------------------------"

  curl -ksSf \
    -H "${AUTH}" \
    -H "Accept: application/json" \
    "${INSTANA_URL}/api/synthetics/settings/tests/${TEST_ID}" \
    > "${BEFORE}"

  TEST_LABEL="$(
    jq -r '.label' "${BEFORE}"
  )"

  echo " Label : ${TEST_LABEL}"

  jq -n \
    --arg app "${APPLICATION_ID}" \
    --arg web "${WEBSITE_ID}" '
    {
      applications: [$app],
      websites: [$web]
    }
  ' > "${PATCH_FILE}"

  echo
  echo "Asociación solicitada:"
  jq . "${PATCH_FILE}"

  HTTP_CODE="$(
    curl -ksS \
      -o "${RESPONSE}" \
      -w '%{http_code}' \
      -X PATCH \
      -H "${AUTH}" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      --data @"${PATCH_FILE}" \
      "${INSTANA_URL}/api/synthetics/settings/tests/${TEST_ID}" \
      || true
  )"

  case "${HTTP_CODE}" in
    200|204)
      echo "[OK] PATCH aceptado HTTP ${HTTP_CODE}"
      ;;
    *)
      echo "[ERROR] PATCH rechazado HTTP ${HTTP_CODE}"
      echo

      if [[ -s "${RESPONSE}" ]]; then
        jq . "${RESPONSE}" 2>/dev/null || cat "${RESPONSE}"
      fi

      echo
      echo "[INFO] Backup:"
      echo "       ${BEFORE}"

      exit 2
      ;;
  esac

  curl -ksSf \
    -H "${AUTH}" \
    -H "Accept: application/json" \
    "${INSTANA_URL}/api/synthetics/settings/tests/${TEST_ID}" \
    > "${AFTER}"

  echo
  echo "Configuración efectiva:"
  jq '{
    id: .id,
    label: .label,
    active: .active,
    applications: .applications,
    applicationLabels: .applicationLabels,
    websites: .websites,
    websiteLabels: .websiteLabels,
    applicationId: .applicationId,
    applicationLabel: .applicationLabel,
    websiteId: .websiteId,
    websiteLabel: .websiteLabel
  }' "${AFTER}"

  if jq -e \
    --arg wid "${WEBSITE_ID}" '
      (.websites // [])
      | index($wid) != null
    ' "${AFTER}" >/dev/null; then

    echo
    echo "[OK] Website asociado correctamente."

  else

    echo
    echo "[ERROR] API aceptó el PATCH pero el Website"
    echo "        no aparece en la configuración efectiva."
    echo
    echo "No continuaremos hasta revisar el modelo devuelto."

    exit 3
  fi

  echo

done

echo "========================================================"
echo " SYNTHETIC ASSOCIATIONS : READY"
echo "========================================================"

#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/opt/instana-demo/instana-api"
STATE_DIR="${BASE_DIR}/state"
OUT_DIR="${STATE_DIR}/synthetic"

source "${BASE_DIR}/00-load-instana-env.sh"

mkdir -p "${OUT_DIR}"

AUTH="Authorization: apiToken ${INSTANA_TOKEN}"

echo
echo "========================================================"
echo " INSTANA API | SYNTHETIC PREFLIGHT"
echo "========================================================"
echo


echo "Consultando Synthetic Locations..."

curl -ksSf \
  -H "${AUTH}" \
  -H "Accept: application/json" \
  "${INSTANA_URL}/api/synthetics/settings/locations" \
  > "${OUT_DIR}/locations.json"

echo "[OK] Locations"


echo "Consultando Synthetic Tests..."

curl -ksSf \
  -H "${AUTH}" \
  -H "Accept: application/json" \
  "${INSTANA_URL}/api/synthetics/settings/tests" \
  > "${OUT_DIR}/tests.json"

echo "[OK] Tests"


echo "Consultando Application Perspectives..."

curl -ksSf \
  -H "${AUTH}" \
  -H "Accept: application/json" \
  "${INSTANA_URL}/api/application-monitoring/applications" \
  > "${OUT_DIR}/applications.json"

echo "[OK] Applications"


echo "Consultando Website..."

curl -ksSf \
  -H "${AUTH}" \
  -H "Accept: application/json" \
  "${INSTANA_URL}/api/website-monitoring/config" \
  > "${OUT_DIR}/websites.json"

echo "[OK] Websites"


echo
echo "========================================================"
echo " SYNTHETIC LOCATIONS"
echo "========================================================"

jq '
  if type == "array"
  then .
  else (.items // .locations // [])
  end
' "${OUT_DIR}/locations.json"


echo
echo "========================================================"
echo " SYNTHETIC TESTS ACTUALES"
echo "========================================================"

jq '
  if type == "array"
  then .
  else (.items // .tests // [])
  end
' "${OUT_DIR}/tests.json"


echo
echo "========================================================"
echo " APPLICATIONS"
echo "========================================================"

jq '
  if type == "array"
  then
    map({
      id: .id,
      name: .name,
      label: .label
    })
  else
    .
  end
' "${OUT_DIR}/applications.json"


echo
echo "========================================================"
echo " WEBSITE NOVA"
echo "========================================================"

jq '
  [
    .[]
    | select(
        .name == "RETAIL - NOVA Market"
      )
  ]
' "${OUT_DIR}/websites.json"


echo
echo "Estado persistido"
echo "--------------------------------------------------------"
echo " ${OUT_DIR}/locations.json"
echo " ${OUT_DIR}/tests.json"
echo " ${OUT_DIR}/applications.json"
echo " ${OUT_DIR}/websites.json"

echo
echo "--------------------------------------------------------"
echo " SYNTHETIC PREFLIGHT : READY"
echo "--------------------------------------------------------"

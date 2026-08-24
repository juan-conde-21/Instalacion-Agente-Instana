#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/opt/instana-demo/instana-api"
STATE_DIR="${BASE_DIR}/state"
OUT_DIR="${STATE_DIR}/synthetic/browser-journey"

source "${BASE_DIR}/00-load-instana-env.sh"

mkdir -p "${OUT_DIR}"

TEST_ID="$(
  tr -d '\r\n' \
  < "${STATE_DIR}/synthetic-nova-browser-journey-id"
)"

AUTH="Authorization: apiToken ${INSTANA_TOKEN}"

REQUEST="${OUT_DIR}/results-request.json"
RESULTS="${OUT_DIR}/results.json"
BASELINE_IDS="${OUT_DIR}/baseline-result-ids.json"
CURRENT="${OUT_DIR}/current-test-results.json"
FRESH="${OUT_DIR}/fresh-results.json"

ORDERS_BEFORE="${OUT_DIR}/orders-before.json"
ORDERS_AFTER="${OUT_DIR}/orders-after.json"


query_results() {

  local to_ms

  to_ms="$(( $(date +%s) * 1000 ))"

  jq -n \
    --argjson to "${to_ms}" '
    {
      pagination: {
        page: 1,
        pageSize: 100
      },

      syntheticMetrics: [
        "synthetic.metricsResponseTime",
        "status",
        "synthetic.errors"
      ],

      order: {
        by: "start_time",
        direction: "DESC"
      },

      timeFrame: {
        to: $to,
        windowSize: 1800000
      }
    }
  ' > "${REQUEST}"

  curl -ksSf \
    -X POST \
    -H "${AUTH}" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    --data @"${REQUEST}" \
    "${INSTANA_URL}/api/synthetics/results/list" \
    > "${RESULTS}"
}


extract_test_results() {

  jq \
    --arg testId "${TEST_ID}" '
      [
        ..
        | objects
        | select(
            (.testId? // "") == $testId
            and
            (.id? != null)
          )
      ]
      | unique_by(.id)
    ' "${RESULTS}"
}


orders_count() {

  jq -r '
    if type == "array" then
      length
    else
      (
        (.items // .orders // [])
        | length
      )
    end
  ' "$1"
}


echo
echo "========================================================"
echo " INSTANA | NOVA BROWSER JOURNEY - FRESH RESULT"
echo "========================================================"
echo
echo " Test ID : ${TEST_ID}"
echo


echo "Negocio"
echo "--------------------------------------------------------"

curl -fsS \
  "http://192.168.252.33:18083/health" \
  | jq .

echo


curl -fsS \
  "http://192.168.252.33:18083/api/orders/valeria" \
  > "${ORDERS_BEFORE}"

BEFORE_COUNT="$(
  orders_count "${ORDERS_BEFORE}"
)"

echo "Pedidos Valeria antes : ${BEFORE_COUNT}"


# --------------------------------------------------------
# Resultados existentes antes de esperar
# --------------------------------------------------------

query_results

extract_test_results \
  > "${CURRENT}"

jq '
  map(.id)
' "${CURRENT}" \
  > "${BASELINE_IDS}"

BASELINE_COUNT="$(
  jq 'length' "${BASELINE_IDS}"
)"

echo "Resultados existentes : ${BASELINE_COUNT}"

echo
echo "Últimos resultados conocidos"
echo "--------------------------------------------------------"

jq '
  .[:5]
  | map({
      id: .id,
      testId: .testId,
      testName: .testName,
      location: .locationDisplayLabel,
      runType: .runType,
      errorCount:
        (
          (.errors // [])
          | length
        )
    })
' "${CURRENT}"


echo
echo "Esperando la SIGUIENTE ejecución Synthetic..."
echo
echo "IMPORTANTE:"
echo " - Esto NO ejecuta el test."
echo " - Instana lo ejecuta cada 1 minuto."
echo " - Nosotros consultamos la API cada 15 segundos."
echo


FOUND=0


for attempt in $(seq 1 12); do

  query_results

  extract_test_results \
    > "${CURRENT}"

  jq \
    --slurpfile baseline "${BASELINE_IDS}" '
      [
        .[]
        | select(
            .id as $resultId
            |
            (
              $baseline[0]
              | index($resultId)
            ) == null
          )
      ]
    ' "${CURRENT}" \
    > "${FRESH}"

  COUNT="$(
    jq 'length' "${FRESH}"
  )"

  if [[ "${COUNT}" -gt 0 ]]; then

    FOUND=1

    echo
    echo "[OK] Nueva ejecución detectada."
    echo "     Consulta ${attempt}/12"

    break
  fi


  echo \
    "[ESPERA] Consulta ${attempt}/12 - " \
    "Instana aún no publicó un Result ID nuevo"


  if [[ "${attempt}" -lt 12 ]]; then
    sleep 15
  fi

done


if [[ "${FOUND}" -ne 1 ]]; then

  echo
  echo "[ERROR] La API no publicó un resultado nuevo"
  echo "        durante la ventana de observación."

  exit 2
fi


echo
echo "========================================================"
echo " NUEVA EJECUCIÓN"
echo "========================================================"


jq '
  .[0]
  | {
      id: .id,
      testId: .testId,
      testName: .testName,
      location:
        .locationDisplayLabel,
      runType: .runType,
      errors:
        (.errors // []),
      errorCount:
        (
          (.errors // [])
          | length
        )
    }
' "${FRESH}"


ERROR_COUNT="$(
  jq '
    (
      .[0].errors //
      []
    )
    | length
  ' "${FRESH}"
)"


echo
echo "Resultado"
echo "--------------------------------------------------------"


if [[ "${ERROR_COUNT}" -eq 0 ]]; then

  echo "[OK] Synthetic PASS"

else

  echo "[FAIL] Synthetic FAIL"
  echo

  jq -r '
    .[0].errors[]
  ' "${FRESH}"

fi


curl -fsS \
  "http://192.168.252.33:18083/api/orders/valeria" \
  > "${ORDERS_AFTER}"

AFTER_COUNT="$(
  orders_count "${ORDERS_AFTER}"
)"


echo
echo "Pedidos Valeria"
echo "--------------------------------------------------------"
echo " Antes   : ${BEFORE_COUNT}"
echo " Después : ${AFTER_COUNT}"


if [[ "${AFTER_COUNT}" -gt "${BEFORE_COUNT}" ]]; then

  echo
  echo "[OK] El Browser Synthetic creó una compra."

else

  echo
  echo "[INFO] No aumentó el contador durante esta"
  echo "       ventana concreta."

fi


echo
echo "--------------------------------------------------------"
echo " BROWSER JOURNEY VALIDATION : COMPLETE"
echo "--------------------------------------------------------"

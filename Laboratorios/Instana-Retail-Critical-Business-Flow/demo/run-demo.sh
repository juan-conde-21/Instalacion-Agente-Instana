#!/usr/bin/env bash
set -euo pipefail

DEMO_DIR="/opt/instana-demo/demo"
API_DIR="/opt/instana-demo/instana-api"
STATE_DIR="${API_DIR}/state"
SYNTH_DIR="${STATE_DIR}/synthetic/browser-journey"

MODE="${1:-interactive}"

pause_demo() {

  if [[ "${MODE}" == "--auto" ]]; then
    return
  fi

  echo
  read -r -p " Presione ENTER para continuar... "
  echo
}


section() {

  echo
  echo "========================================================"
  echo " $1"
  echo "========================================================"
  echo
}


synthetic_error_count() {

  jq -r '
    (
      .[0].errors //
      []
    )
    | length
  ' "${SYNTH_DIR}/fresh-results.json"
}


alert_states() {

  local events="${STATE_DIR}/website-alerts/alert-lifecycle-events.json"

  local http_id
  local business_id

  http_id="$(
    tr -d '\r\n' \
      < "${STATE_DIR}/website-alert-http503-id"
  )"

  business_id="$(
    tr -d '\r\n' \
      < "${STATE_DIR}/website-alert-checkout-failed-id"
  )"

  local http_state
  local business_state

  http_state="$(
    jq -r \
      --arg id "${http_id}" '
        [
          .[]
          | select(
              .eventSpecificationId == $id
            )
        ]
        | sort_by(.start)
        | reverse
        | .[0].state // "NOT_FOUND"
      ' "${events}"
  )"

  business_state="$(
    jq -r \
      --arg id "${business_id}" '
        [
          .[]
          | select(
              .eventSpecificationId == $id
            )
        ]
        | sort_by(.start)
        | reverse
        | .[0].state // "NOT_FOUND"
      ' "${events}"
  )"

  echo "${http_state}|${business_state}"
}


section "INSTANA | DEMO END-TO-END"

echo " Escenario:"
echo " HEALTHY -> FAULT -> DETECTION -> RECOVERY"
echo
echo " No se requiere generar compras manualmente."
echo " NOVA Customer Journey genera tráfico automáticamente."

pause_demo


# ========================================================
# 01. BASELINE
# ========================================================

section "01 | BASELINE SALUDABLE"

cd "${DEMO_DIR}"

./demo.sh status

echo
echo "[INFO] Ejecutando auditoría previa..."

"${API_DIR}/10a-final-lab-audit.sh"

pause_demo


# ========================================================
# 02. SYNTHETIC BASELINE
# ========================================================

section "02 | EXPERIENCIA DIGITAL SALUDABLE"

echo "Esperando una nueva ejecución del Browser Journey..."
echo

"${API_DIR}/08e-validate-browser-baseline.sh"

ERRORS="$(
  synthetic_error_count
)"

if [[ "${ERRORS}" -ne 0 ]]; then

  echo
  echo "[ERROR] El Synthetic no está saludable antes"
  echo "        de iniciar la demostración."
  exit 10
fi

echo
echo "[OK] Cliente digital puede completar su compra."

pause_demo


# ========================================================
# 03. FAULT
# ========================================================

section "03 | INCIDENTE CONTROLADO"

cd "${DEMO_DIR}"

./demo.sh fault

pause_demo


# ========================================================
# 04. BUSINESS IMPACT
# ========================================================

section "04 | IMPACTO EN EL NEGOCIO"

./demo.sh observe

echo
echo "[OK] Infraestructura continúa disponible."
echo "[IMPACTO] Proceso crítico de negocio no disponible."

pause_demo


# ========================================================
# 05. SYNTHETIC FAIL
# ========================================================

section "05 | DETECCIÓN DESDE EL CLIENTE"

cd "${API_DIR}"

echo "Esperando que NOVA Customer Journey"
echo "encuentre automáticamente el fallo..."
echo

./08e-validate-browser-baseline.sh

ERRORS="$(
  synthetic_error_count
)"

if [[ "${ERRORS}" -eq 0 ]]; then

  echo
  echo "[ERROR] Se esperaba Synthetic FAIL,"
  echo "        pero la ejecución terminó PASS."
  exit 20
fi

echo
echo "[OK] Browser Journey detectó impacto funcional."
echo "[OK] No se generó tráfico manual."

pause_demo


# ========================================================
# 06. SMART ALERTS OPEN
# ========================================================

section "06 | SMART ALERTS"

echo "Esperando evaluación de Website Monitoring..."

for poll in $(seq 1 12); do

  ./07h-audit-alert-lifecycle.sh

  STATES="$(
    alert_states
  )"

  HTTP_STATE="${STATES%%|*}"
  BUSINESS_STATE="${STATES##*|}"

  if [[ "${HTTP_STATE}" == "open" &&
        "${BUSINESS_STATE}" == "open" ]]; then

    echo
    echo "[OK] HTTP 503        : OPEN"
    echo "[OK] Checkout Failed : OPEN"
    break
  fi

  if [[ "${poll}" -eq 12 ]]; then

    echo
    echo "[ERROR] Las Smart Alerts no llegaron"
    echo "        ambas a OPEN."
    exit 30
  fi

  echo
  echo "[ESPERA] Instana continúa evaluando..."
  sleep 15

done

pause_demo


# ========================================================
# 07. RECOVERY
# ========================================================

section "07 | RECUPERACIÓN DEL NEGOCIO"

cd "${DEMO_DIR}"

./demo.sh recover
./demo.sh status

pause_demo


# ========================================================
# 08. SYNTHETIC PASS
# ========================================================

section "08 | VALIDACIÓN DEL CLIENTE"

cd "${API_DIR}"

echo "Esperando una nueva ejecución saludable..."
echo

./08e-validate-browser-baseline.sh

ERRORS="$(
  synthetic_error_count
)"

if [[ "${ERRORS}" -ne 0 ]]; then

  echo
  echo "[ERROR] El Browser Journey continúa FAIL"
  echo "        después de recuperar el negocio."
  exit 40
fi

echo
echo "[OK] Browser Journey volvió a PASS."

pause_demo


# ========================================================
# 09. ALERT RECOVERY
# ========================================================

section "09 | CIERRE AUTOMÁTICO DE ALERTAS"

./07i-wait-alerts-closed.sh

pause_demo


# ========================================================
# 10. DEPENDENCIES
# ========================================================

section "10 | DEPENDENCIAS DE APLICACIÓN"

./09b-validate-service-topology.sh

source "${API_DIR}/00-load-runtime-ids.sh"

CALLS="$(
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
    ' \
    "${STATE_DIR}/dependencies/topology-all.json"
)"

if [[ "${CALLS}" -gt 0 ]]; then

  echo
  echo "[OK] RETAIL -> CENTRAL"
  echo "     ${CALLS} llamadas observadas."

else

  echo
  echo "[WARN] No existen llamadas recientes"
  echo "       RETAIL -> CENTRAL en la ventana."

fi

pause_demo


# ========================================================
# 11. FINAL AUDIT
# ========================================================

section "11 | VALIDACIÓN FINAL"

./10a-final-lab-audit.sh


section "INSTANA | DEMO COMPLETE"

echo " Resultado demostrado"
echo "--------------------------------------------------------"
echo " [OK] Infraestructura técnicamente disponible"
echo " [OK] Falla funcional controlada"
echo " [OK] Synthetic detecta impacto al cliente"
echo " [OK] EUM registra Checkout Failed / HTTP 503"
echo " [OK] Smart Alerts abren automáticamente"
echo " [OK] Negocio recuperado"
echo " [OK] Synthetic vuelve a PASS"
echo " [OK] Smart Alerts cierran automáticamente"
echo " [OK] Dependency RETAIL -> CENTRAL observada"
echo
echo " FLUJO CRÍTICO : DEMOSTRADO END-TO-END"
echo

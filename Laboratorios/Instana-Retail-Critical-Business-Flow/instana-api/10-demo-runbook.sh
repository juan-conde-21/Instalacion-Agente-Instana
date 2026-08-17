#!/usr/bin/env bash
set -uo pipefail

BASE_DIR="/opt/instana-demo/instana-api"
LOG_DIR="${BASE_DIR}/logs"

mkdir -p "${LOG_DIR}"

cd "${BASE_DIR}"

# ============================================================
# COLORS
# ============================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

ok() {
    printf "${GREEN}[OK]   ${RESET} %-27s ${GREEN}%s${RESET}\n" "$1" "$2"
}

bad() {
    printf "${RED}[FAIL] ${RESET} %-27s ${RED}%s${RESET}\n" "$1" "$2"
}

warn() {
    printf "${YELLOW}[WARN] ${RESET} %-27s ${YELLOW}%s${RESET}\n" "$1" "$2"
}

title() {
    echo
    printf "${BOLD}${CYAN}========================================================${RESET}\n"
    printf "${BOLD}${CYAN} %s${RESET}\n" "$1"
    printf "${BOLD}${CYAN}========================================================${RESET}\n"
    echo
}

run_internal() {

    local name="$1"
    local script="$2"

    LAST_LOG="${LOG_DIR}/${name}-$(date +%Y%m%d-%H%M%S).log"

    set +e
    "${script}" >"${LAST_LOG}" 2>&1
    INTERNAL_RC=$?
    set -e 2>/dev/null || true
}

show_error() {

    bad "Resultado" "CHECK REQUIRED"

    echo
    echo "Detalle técnico:"
    echo "  ${LAST_LOG}"
    echo
}


# ============================================================
# STATUS
# ============================================================

demo_status() {

    title "RETAIL - CRITICAL BUSINESS FLOW"

    run_internal \
      "status" \
      "${BASE_DIR}/06-demo-status.sh"

    if grep -q \
      'DEMO STATE = HEALTHY' \
      "${LAST_LOG}"; then

        ok "Distribución"         "OK"
        ok "Archivo crítico"      "READY"
        ok "Aplicación"           "UP"
        ok "Operación de negocio" "SUCCESS"

        echo
        printf "${GREEN}${BOLD}ESTADO GENERAL             HEALTHY${RESET}\n"

    else

        show_error
        return 1
    fi
}


# ============================================================
# FAULT
# ============================================================

demo_fault() {

    title "SIMULACIÓN - FALLA DE DISTRIBUCIÓN"

    warn "Acción" "Interrumpiendo distribución..."

    run_internal \
      "fault" \
      "${BASE_DIR}/07-demo-fault.sh"

    if grep -q \
      'FAULT INJECTION = PASS' \
      "${LAST_LOG}"; then

        echo
        bad  "Distribución"    "BLOCKED"
        ok   "Infraestructura" "UP"
        ok   "Aplicación"      "UP"
        warn "Negocio"         "Esperando vencimiento del archivo"

        echo
        printf "${YELLOW}${BOLD}FALLA INYECTADA             ACTIVE${RESET}\n"

    else

        show_error
        return 1
    fi
}


# ============================================================
# OBSERVE
# ============================================================

demo_observe() {

    title "INSTANA - IMPACTO DE NEGOCIO"

    warn "Observación" \
         "Esperando condición de impacto..."

    run_internal \
      "observe" \
      "${BASE_DIR}/08-demo-observe.sh"

    if grep -q \
      'BUSINESS IMPACT OBSERVATION = PASS' \
      "${LAST_LOG}"; then

        echo
        ok  "Infraestructura"       "UP"
        ok  "Aplicación"            "UP"
        bad "Archivo crítico"       "STALE"
        bad "Operación de negocio"  "FAILED"

        echo
        printf "${GREEN}${BOLD}ESTADO TÉCNICO             HEALTHY${RESET}\n"
        printf "${RED}${BOLD}ESTADO DE NEGOCIO          IMPACTED${RESET}\n"

        echo
        printf "${BOLD}Mensaje:${RESET}\n"
        echo "La plataforma continúa disponible,"
        echo "pero el proceso crítico de negocio está afectado."

    else

        show_error
        return 1
    fi
}


# ============================================================
# RECOVER
# ============================================================

demo_recover() {

    title "RECUPERACIÓN DEL SERVICIO"

    warn "Acción" "Restaurando distribución..."

    run_internal \
      "recover" \
      "${BASE_DIR}/09-demo-recover.sh"

    if grep -q \
      'BUSINESS RECOVERY = PASS' \
      "${LAST_LOG}"; then

        echo
        ok "Distribución"         "RESTORED"
        ok "Archivo crítico"      "READY"
        ok "Aplicación"           "UP"
        ok "Operación de negocio" "SUCCESS"

        echo
        printf "${GREEN}${BOLD}ESTADO GENERAL             RECOVERED${RESET}\n"

    else

        show_error
        return 1
    fi
}


# ============================================================
# INSTANA SLO
# ============================================================

percentage() {
    awk -v value="$1" \
      'BEGIN { printf "%.2f%%", value * 100 }'
}


slo_line() {

    local label="$1"
    local file="$2"

    local sli
    local slo
    local meets

    sli=$(jq -r '.sli // empty' "${file}")
    slo=$(jq -r '.slo // empty' "${file}")

    if [[ -z "${sli}" || -z "${slo}" ]]; then
        warn "${label}" "NO DATA"
        return
    fi

    meets=$(
      awk \
        -v sli="${sli}" \
        -v slo="${slo}" \
        'BEGIN { print (sli >= slo ? 1 : 0) }'
    )

    if [[ "${meets}" == "1" ]]; then

        ok "${label}" \
           "$(percentage "${sli}")  | objetivo $(percentage "${slo}")"

    else

        bad "${label}" \
            "$(percentage "${sli}")  | objetivo $(percentage "${slo}")"
    fi
}


demo_instana() {

    title "INSTANA - BUSINESS RELIABILITY"

    if [[ -z "${INSTANA_TOKEN:-}" ]]; then

        source \
          "${BASE_DIR}/00-load-instana-env.sh" \
          >/dev/null

    fi

    TECH_SLO_ID=$(cat "${BASE_DIR}/state/slo-technical-id")
    BUS_SLO_ID=$(cat "${BASE_DIR}/state/slo-business-id")

    TO_MS=$(($(date +%s) * 1000))
    FROM_MS=$((TO_MS - 1800000))

    TECH_FILE=$(mktemp)
    BUS_FILE=$(mktemp)

    TECH_HTTP=$(
      curl -skS \
        -o "${TECH_FILE}" \
        -w '%{http_code}' \
        -H "Authorization: apiToken ${INSTANA_TOKEN}" \
        -H "Accept: application/json" \
        "${INSTANA_URL}/api/slo/report/${TECH_SLO_ID}?from=${FROM_MS}&to=${TO_MS}"
    )

    BUS_HTTP=$(
      curl -skS \
        -o "${BUS_FILE}" \
        -w '%{http_code}' \
        -H "Authorization: apiToken ${INSTANA_TOKEN}" \
        -H "Accept: application/json" \
        "${INSTANA_URL}/api/slo/report/${BUS_SLO_ID}?from=${FROM_MS}&to=${TO_MS}"
    )

    if [[ "${TECH_HTTP}" == "200" ]]; then

        slo_line \
          "Disponibilidad técnica" \
          "${TECH_FILE}"

    else

        warn \
          "Disponibilidad técnica" \
          "REPORT HTTP ${TECH_HTTP}"
    fi


    if [[ "${BUS_HTTP}" == "200" ]]; then

        slo_line \
          "Disponibilidad de negocio" \
          "${BUS_FILE}"

        REMAINING=$(
          jq -r \
            '.errorBudgetRemaining // "N/A"' \
            "${BUS_FILE}"
        )

        TOTAL=$(
          jq -r \
            '.totalErrorBudget // "N/A"' \
            "${BUS_FILE}"
        )

        SPENT=$(
          jq -r \
            '.errorBudgetSpent // "N/A"' \
            "${BUS_FILE}"
        )

        if [[ "${REMAINING}" != "N/A" ]] \
          && [[ "${REMAINING}" =~ ^-?[0-9]+$ ]]; then

            if (( REMAINING > 0 )); then

                warn \
                  "Presupuesto de error" \
                  "${REMAINING}/${TOTAL} remaining | ${SPENT} spent"

            else

                bad \
                  "Presupuesto de error" \
                  "${REMAINING}/${TOTAL} remaining | ${SPENT} spent"
            fi

        else

            warn "Presupuesto de error" "NO DATA"
        fi

    else

        warn \
          "Disponibilidad de negocio" \
          "REPORT HTTP ${BUS_HTTP}"

        warn \
          "Presupuesto de error" \
          "REPORT UNAVAILABLE"
    fi

    rm -f "${TECH_FILE}" "${BUS_FILE}"

    echo
    printf "${BOLD}Ventana de análisis:${RESET} últimos 30 minutos\n"
}


# ============================================================
# USAGE
# ============================================================

usage() {

    title "RETAIL DEMO"

    echo "Comandos:"
    echo
    echo "  ./10-demo-runbook.sh status"
    echo "  ./10-demo-runbook.sh fault"
    echo "  ./10-demo-runbook.sh observe"
    echo "  ./10-demo-runbook.sh recover"
    echo "  ./10-demo-runbook.sh instana"

    echo
    echo "Secuencia:"
    echo
    echo "  status -> fault -> observe -> instana -> recover -> instana"
    echo
}


COMMAND="${1:-}"

case "${COMMAND}" in

    status)
        demo_status
        ;;

    fault)
        demo_fault
        ;;

    observe)
        demo_observe
        ;;

    recover)
        demo_recover
        ;;

    instana)
        demo_instana
        ;;

    *)
        usage
        exit 1
        ;;

esac

echo

#!/usr/bin/env bash
set -euo pipefail

BASE="/opt/instana-demo"
API="${BASE}/instana-api"
DEMO="${BASE}/demo"
LOG_DIR="${DEMO}/logs"

source "${DEMO}/lib/demo-ui.sh"

mkdir -p "${LOG_DIR}"

ACTION="${1:-}"
MODE="${2:-}"

STATE_LOG=""
CURRENT_PERMS=""
CURRENT_FILE_STATUS=""
CURRENT_BUSINESS_HTTP=""
CURRENT_STATE="UNKNOWN"


require_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        echo
        echo "ERROR: ejecutar la demo en el Bastion como usuario root."
        echo
        exit 1
    fi
}


usage() {
    echo
    echo "Instana Critical Negocio Flow Demo"
    echo
    echo "Ejecutar en Bastion como root:"
    echo
    echo "  ./demo.sh status"
    echo "  ./demo.sh fault"
    echo "  ./demo.sh observe"
    echo "  ./demo.sh recover"
    echo
    echo "Detalle tecnico:"
    echo "  ./demo.sh <accion> --verbose"
    echo
}


technical_script() {
    case "$1" in
        status)  echo "${API}/06-demo-status.sh" ;;
        fault)   echo "${API}/07-demo-fault.sh" ;;
        observe) echo "${API}/08-demo-observe.sh" ;;
        recover) echo "${API}/09-demo-recover.sh" ;;
        runbook) echo "${API}/10-demo-runbook.sh" ;;
        *) return 1 ;;
    esac
}


run_verbose() {
    local script

    script="$(technical_script "${ACTION}")"
    exec "${script}"
}


run_background() {
    local script="$1"
    local log="$2"
    local message="$3"
    local pid rc

    "${script}" >"${log}" 2>&1 &
    pid=$!

    ui_spinner "${pid}" "${message}"

    set +e
    wait "${pid}"
    rc=$?
    set -e

    return "${rc}"
}


show_failure() {
    local log="$1"

    echo
    ui_fail "Ejecución técnica" "FAILED"

    echo
    echo "Detalle tecnico:"
    echo "  ${log}"

    echo
    echo "Ultimas lineas:"
    tail -15 "${log}" 2>/dev/null || true
}


show_validation_failure() {
    echo
    ui_fail "Validación de estado" "FAILED"

    echo
    echo "La acción terminó, pero no fue posible confirmar"
    echo "de forma independiente el estado esperado del negocio."

    echo
    echo "Detalle tecnico:"
    echo "  ${STATE_LOG}"
}


detect_state() {
    STATE_LOG="${LOG_DIR}/state-$(date +%Y%m%d-%H%M%S)-$$.log"

    if ! "${API}/06-demo-status.sh" >"${STATE_LOG}" 2>&1; then
        CURRENT_STATE="ERROR"
        return 1
    fi

    CURRENT_PERMS="$(
        awk -F= '/^PERMS=/{print $2; exit}' \
        "${STATE_LOG}" 2>/dev/null || true
    )"

    CURRENT_FILE_STATUS="$(
        grep 'Status Body' "${STATE_LOG}" 2>/dev/null \
        | grep -o '"status":"[^"]*"' \
        | tail -1 \
        | cut -d'"' -f4 \
        || true
    )"

    CURRENT_BUSINESS_HTTP="$(
        awk '/^Negocio HTTP/{print $NF; exit}' \
        "${STATE_LOG}" 2>/dev/null || true
    )"

    #
    # IMPORTANTE:
    # La distribucion bloqueada tiene prioridad sobre
    # DEMO STATE = HEALTHY porque existe una ventana
    # donde el archivo aun sigue READY.
    #
    if [[ "${CURRENT_PERMS}" == "555" ]]; then

        if [[ "${CURRENT_FILE_STATUS}" == "STALE" ]]; then
            CURRENT_STATE="IMPACTED"
        else
            CURRENT_STATE="INCIDENT"
        fi

    elif grep -q "DEMO STATE = HEALTHY" "${STATE_LOG}"; then

        CURRENT_STATE="HEALTHY"

    else

        CURRENT_STATE="DEGRADED"

    fi
}


show_next() {
    echo
    printf "${UI_BLUE}${UI_BOLD}"
    echo " Siguiente paso"
    echo "--------------------------------------------------------"
    printf "${UI_RESET}"

    printf " %s\n" "$1"
}


status_exec() {

    ui_header "ESTADO DEL PROCESO CRÍTICO"
    ui_context

    ui_section "Proceso de negocio"

    if ! detect_state; then
        show_failure "${STATE_LOG}"
        exit 1
    fi

    case "${CURRENT_STATE}" in

        HEALTHY)

            ui_ok "ORIGEN" "Generando información"
            ui_ok "CENTRAL" "Disponible"
            ui_ok "RETAIL" "Disponible"
            ui_ok "Archivo crítico" "READY"
            ui_ok "Negocio" "Transacción exitosa"

            ui_result_ok "HEALTHY"

            show_next "./demo.sh fault"
            ;;


        INCIDENT)

            ui_ok "ORIGEN" "Continúa generando información"
            ui_ok "CENTRAL" "Disponible"
            ui_ok "RETAIL" "Disponible"
            ui_fail "Distribución" "INTERRUMPIDA"
            ui_wait "Archivo crítico" "Esperando condición STALE"

            echo
            printf "${UI_YELLOW}${UI_BOLD}"
            echo " INCIDENTE CONTROLADO ACTIVE"
            printf "${UI_RESET}"

            show_next "./demo.sh observe"
            ;;


        IMPACTED)

            ui_ok "ORIGEN" "Continúa generando información"
            ui_ok "CENTRAL" "UP"
            ui_ok "RETAIL" "UP"
            ui_fail "Distribución" "INTERRUMPIDA"
            ui_fail "Archivo crítico" "STALE"
            ui_fail "Negocio" "NO DISPONIBLE"

            ui_result_fail "NO DISPONIBLE"

            echo
            printf "${UI_RED}${UI_BOLD}"
            echo " Los servicios técnicos continúan disponibles,"
            echo " pero el proceso crítico de negocio no está disponible."
            printf "${UI_RESET}"

            show_next "./demo.sh recover"
            ;;


        DEGRADED)

            ui_fail "Ambiente" "DEGRADED"

            echo
            echo "El ambiente no se encuentra en un estado seguro"
            echo "para ejecutar la demostración controlada."

            echo
            echo "Detalle tecnico:"
            echo "  ${STATE_LOG}"

            exit 1
            ;;


        *)

            ui_fail "Ambiente" "UNKNOWN"

            echo
            echo "Detalle tecnico:"
            echo "  ${STATE_LOG}"

            exit 1
            ;;
    esac
}


fault_exec() {

    local log="${LOG_DIR}/fault-$(date +%Y%m%d-%H%M%S).log"

    ui_header "INCIDENTE CONTROLADO"
    ui_context

    if ! detect_state; then
        show_failure "${STATE_LOG}"
        exit 1
    fi


    if [[ "${CURRENT_STATE}" == "INCIDENT" || \
          "${CURRENT_STATE}" == "IMPACTED" ]]; then

        ui_section "Escenario"

        ui_info "Incident" "Ya se encuentra activo"
        ui_fail "Distribución" "INTERRUMPIDA"

        if [[ "${CURRENT_STATE}" == "IMPACTED" ]]; then
            ui_fail "Negocio" "El negocio ya se encuentra impactado"
            show_next "./demo.sh recover"
        else
            ui_wait "Negocio impact" "Esperando condición STALE"
            show_next "./demo.sh observe"
        fi

        echo
        printf "${UI_YELLOW}${UI_BOLD}"
        echo " No se inyectó una falla adicional."
        printf "${UI_RESET}"

        return 0
    fi


    if [[ "${CURRENT_STATE}" != "HEALTHY" ]]; then

        ui_fail "Ambiente" "No está listo para inyectar la falla"

        echo
        echo "Run:"
        echo "  ./demo.sh status --verbose"

        exit 1
    fi


    ui_section "Escenario"

    ui_info "Acción" "Interrumpiendo distribución del archivo crítico"
    ui_ok "CENTRAL" "Permanece disponible"
    ui_ok "RETAIL" "Permanece disponible"

    echo


    if ! run_background \
        "${API}/07-demo-fault.sh" \
        "${log}" \
        "Activating controlled incident"
    then

        show_failure "${log}"
        exit 1
    fi


    #
    # VALIDACION INDEPENDIENTE
    #
    if ! detect_state; then
        show_validation_failure
        exit 1
    fi


    if [[ "${CURRENT_STATE}" != "INCIDENT" && \
          "${CURRENT_STATE}" != "IMPACTED" ]]; then

        show_validation_failure

        echo
        echo "Esperado:"
        echo "  Distribución = INTERRUMPIDA"
        echo
        echo "Estado detectado:"
        echo "  ${CURRENT_STATE}"

        exit 1
    fi


    ui_fail "Distribución" "INTERRUMPIDA"
    ui_ok "Capa técnica" "Permanece disponible"

    echo

    if [[ "${CURRENT_STATE}" == "IMPACTED" ]]; then

        ui_fail "Archivo crítico" "STALE"
        ui_fail "Negocio" "NO DISPONIBLE"

        show_next "./demo.sh recover"

    else

        ui_wait "Negocio impact" "Esperado al superar 120s sin actualización"

        echo
        printf "${UI_BLUE}${UI_BOLD}"
        echo " La aplicación continúa operativa mientras utiliza la última
 información comercial disponible.

 El impacto de negocio aparecerá cuando la información supere
 el umbral de vigencia de 120 segundos.

 [ESPERA]   Próxima validación     Espere ~60-120s y ejecute ./demo.sh observe

 Instana continúa observando el proceso."
        printf "${UI_RESET}"

        show_next "./demo.sh observe"

    fi
}


observe_exec() {

    local log="${LOG_DIR}/observe-$(date +%Y%m%d-%H%M%S).log"

    ui_header "IMPACTO EN EL NEGOCIO"
    ui_context

    if ! detect_state; then
        show_failure "${STATE_LOG}"
        exit 1
    fi


    if [[ "${CURRENT_STATE}" == "HEALTHY" ]]; then

        ui_section "Escenario"

        ui_ok "Distribución" "HABILITADA"
        ui_ok "Archivo crítico" "READY"
        ui_ok "Negocio flow" "HEALTHY"

        echo
        printf "${UI_BLUE}${UI_BOLD}"
        echo " No existe un incidente activo para observar."
        printf "${UI_RESET}"

        show_next "./demo.sh fault"

        return 0
    fi


    if [[ "${CURRENT_STATE}" == "IMPACTED" ]]; then

        ui_section "Disponibilidad técnica"

        ui_ok "CENTRAL" "UP"
        ui_ok "RETAIL" "UP"
        ui_ok "HTTP health" "200"

        echo

        ui_section "Disponibilidad del negocio"

        ui_fail "Distribución" "INTERRUMPIDA"
        ui_fail "Archivo crítico" "STALE"
        ui_fail "Transacción" "FAILED"
        ui_fail "HTTP de negocio" "503"

        ui_result_fail "NO DISPONIBLE"

        show_next "./demo.sh recover"

        return 0
    fi


    ui_section "Esperando degradación funcional"

    ui_ok "ORIGEN" "Continúa generando información"
    ui_fail "Distribución" "INTERRUMPIDA"
    ui_wait "Archivo crítico" "Esperando condición STALE"

    echo


    if ! run_background \
        "${API}/08-demo-observe.sh" \
        "${log}" \
        "Waiting for business impact"
    then

        show_failure "${log}"
        exit 1
    fi


    #
    # VALIDACION INDEPENDIENTE DEL IMPACTO
    #
    if ! detect_state; then
        show_validation_failure
        exit 1
    fi


    if [[ "${CURRENT_STATE}" != "IMPACTED" ]]; then

        show_validation_failure

        echo
        echo "Esperado:"
        echo "  Archivo crítico = STALE"
        echo "  Negocio      = NO DISPONIBLE"
        echo
        echo "Estado detectado:"
        echo "  ${CURRENT_STATE}"

        exit 1
    fi


    ui_section "Disponibilidad técnica"

    ui_ok "CENTRAL" "UP"
    ui_ok "RETAIL" "UP"
    ui_ok "HTTP health" "200"

    echo

    ui_section "Disponibilidad del negocio"

    ui_fail "Distribución" "INTERRUMPIDA"
    ui_fail "Archivo crítico" "STALE"
    ui_fail "Transacción" "FAILED"
    ui_fail "HTTP de negocio" "503"

    ui_result_fail "NO DISPONIBLE"

    echo
    printf "${UI_RED}${UI_BOLD}"
    echo " La disponibilidad técnica continúa saludable,"
    echo " pero el proceso crítico de negocio no está disponible."
    printf "${UI_RESET}"

    show_next "./demo.sh recover"
}


recover_exec() {

    local log="${LOG_DIR}/recover-$(date +%Y%m%d-%H%M%S).log"

    ui_header "RECUPERACIÓN DEL NEGOCIO"
    ui_context

    if ! detect_state; then
        show_failure "${STATE_LOG}"
        exit 1
    fi


    if [[ "${CURRENT_STATE}" == "HEALTHY" ]]; then

        ui_section "Recuperación"

        ui_ok "Distribución" "HABILITADA"
        ui_ok "Archivo crítico" "READY"
        ui_ok "Negocio flow" "Ya se encuentra saludable"

        echo
        printf "${UI_GREEN}${UI_BOLD}"
        echo " No se requiere ninguna acción de recuperación."
        printf "${UI_RESET}"

        ui_result_ok "HEALTHY"

        show_next "./demo.sh fault"

        return 0
    fi


    ui_section "Recuperación"

    ui_info "Distribución" "Restaurando flujo de información"

    echo


    if ! run_background \
        "${API}/09-demo-recover.sh" \
        "${log}" \
        "Recuperando proceso de negocio"
    then

        show_failure "${log}"
        exit 1
    fi


    #
    # VALIDACION INDEPENDIENTE
    #
    if ! detect_state; then
        show_validation_failure
        exit 1
    fi


    if [[ "${CURRENT_STATE}" != "HEALTHY" ]]; then

        show_validation_failure

        echo
        echo "Esperado:"
        echo "  Distribución = HABILITADA"
        echo "  Archivo crítico = READY"
        echo "  Negocio = HEALTHY"
        echo
        echo "Estado detectado:"
        echo "  ${CURRENT_STATE}"

        exit 1
    fi


    ui_ok "Distribución" "HABILITADA"
    ui_ok "Archivo crítico" "READY"
    ui_ok "CENTRAL" "UP"
    ui_ok "RETAIL" "UP"
    ui_ok "Transacción" "SUCCESS"
    ui_ok "HTTP de negocio" "200"

    ui_result_ok "RECUPERADO"

    echo
    printf "${UI_GREEN}${UI_BOLD}"
    echo " Recuperación validada de forma independiente."
    printf "${UI_RESET}"

    show_next "./demo.sh status"
}


require_root


if [[ "${MODE}" == "--verbose" ]]; then
    run_verbose
fi


case "${ACTION}" in

    status)
        status_exec
        ;;

    fault)
        fault_exec
        ;;

    observe)
        observe_exec
        ;;

    recover)
        recover_exec
        ;;

    runbook)
        run_verbose
        ;;

    *)
        usage
        exit 2
        ;;
esac

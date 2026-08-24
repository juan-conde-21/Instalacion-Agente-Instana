#!/usr/bin/env bash

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    UI_RESET=$'\033[0m'
    UI_BOLD=$'\033[1m'
    UI_DIM=$'\033[2m'

    UI_BLUE=$'\033[1;34m'
    UI_GREEN=$'\033[1;32m'
    UI_YELLOW=$'\033[1;33m'
    UI_RED=$'\033[1;31m'
else
    UI_RESET=""
    UI_BOLD=""
    UI_DIM=""
    UI_BLUE=""
    UI_GREEN=""
    UI_YELLOW=""
    UI_RED=""
fi


ui_header() {
    local title="$1"

    echo
    printf "${UI_BLUE}${UI_BOLD}"
    echo "========================================================"
    printf " INSTANA | %s\n" "${title}"
    echo "========================================================"
    printf "${UI_RESET}"
    echo
}


ui_section() {
    printf "${UI_BLUE}${UI_BOLD}%s${UI_RESET}\n" "$1"
    echo "--------------------------------------------------------"
}


ui_ok() {
    printf " ${UI_GREEN}[OK]${UI_RESET}     %-20s %s\n" "$1" "${2:-}"
}


ui_info() {
    printf " ${UI_BLUE}[INFO]${UI_RESET}   %-20s %s\n" "$1" "${2:-}"
}


ui_wait() {
    printf " ${UI_YELLOW}[ESPERA]${UI_RESET}   %-20s %s\n" "$1" "${2:-}"
}


ui_fail() {
    printf " ${UI_RED}[IMPACTO]${UI_RESET} %-20s %s\n" "$1" "${2:-}"
}


ui_result_ok() {
    echo
    printf "${UI_GREEN}${UI_BOLD}"
    echo "--------------------------------------------------------"
    printf " FLUJO DE NEGOCIO : %s\n" "$1"
    echo "--------------------------------------------------------"
    printf "${UI_RESET}"
}


ui_result_fail() {
    echo
    printf "${UI_RED}${UI_BOLD}"
    echo "--------------------------------------------------------"
    printf " FLUJO DE NEGOCIO : %s\n" "$1"
    echo "--------------------------------------------------------"
    printf "${UI_RESET}"
}


ui_context() {
    ui_section "Contexto de ejecución"
    ui_info "Servidor" "$(hostname)"
    ui_info "Usuario" "$(whoami)"
    echo
}


ui_spinner() {
    local pid="$1"
    local message="$2"
    local start now elapsed
    local spin='|/-\'
    local i=0

    start="$(date +%s)"

    while kill -0 "${pid}" 2>/dev/null; do
        now="$(date +%s)"
        elapsed=$((now - start))

        printf "\r ${UI_YELLOW}[ESPERA]${UI_RESET}   %-30s %3ss %s" \
            "${message}" "${elapsed}" "${spin:i++%4:1}"

        sleep 1
    done

    printf "\r\033[K"
}

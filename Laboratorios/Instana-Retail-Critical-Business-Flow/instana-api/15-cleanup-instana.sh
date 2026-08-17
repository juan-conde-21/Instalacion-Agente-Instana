#!/usr/bin/env bash
set -uo pipefail

BASE_DIR="/opt/instana-demo"
API_DIR="${BASE_DIR}/instana-api"
STATE_DIR="${API_DIR}/state"
CONFIG_DIR="${API_DIR}/config"

INVENTORY="${CONFIG_DIR}/cleanup-inventory.json"

source "${API_DIR}/00-load-runtime-env.sh"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

MODE="DRY_RUN"

if [[ "${1:-}" == "--execute" ]]; then
    MODE="EXECUTE"
elif [[ -n "${1:-}" ]]; then
    echo "Uso:"
    echo "  ./15-cleanup-instana.sh"
    echo "  ./15-cleanup-instana.sh --execute"
    exit 1
fi

ok() {
    printf "${GREEN}[OK]   ${RESET} %-31s %s\n" "$1" "${2:-}"
}

fail() {
    printf "${RED}[FAIL] ${RESET} %-31s %s\n" "$1" "${2:-}"
}

warn() {
    printf "${YELLOW}[WARN] ${RESET} %-31s %s\n" "$1" "${2:-}"
}

section() {
    echo
    printf "${BOLD}${CYAN}%s${RESET}\n" "$1"
}

read_state() {
    local name="$1"

    if [[ -s "${STATE_DIR}/${name}" ]]; then
        tr -d '\r\n' < "${STATE_DIR}/${name}"
    fi
}


# ============================================================
# SAFETY GATE
# ============================================================

if [[ ! -s "${INVENTORY}" ]]; then

    fail "Cleanup inventory" "MISSING"
    echo
    echo "Ejecute primero:"
    echo "  ./14-inventory-before-cleanup.sh"
    exit 1
fi


READY=$(
    jq -r '.readyForCleanup // false' \
      "${INVENTORY}"
)

MATCHES=$(
    jq '[.objects[] | select(.status == "MATCH")] | length' \
      "${INVENTORY}"
)


if [[ "${READY}" != "true" || "${MATCHES}" != "8" ]]; then

    fail "Cleanup inventory" "NOT APPROVED"
    exit 1
fi


# ============================================================
# STATE IDS
# ============================================================

APPLICATION_ID=$(read_state application-id)

SYNTH_TECH_ID=$(read_state synthetic-technical-id)
SYNTH_BUSINESS_ID=$(read_state synthetic-business-id)

ALERT_ID=$(read_state synthetic-business-alert-id)

SLO_TECH_ID=$(read_state slo-technical-id)
SLO_BUSINESS_ID=$(read_state slo-business-id)

DASHBOARD_ID=$(read_state dashboard-id)

LOCATION_ID=$(read_state synthetic-location-id)


# ============================================================
# VERIFY ID IS APPROVED
# ============================================================

approved() {

    local type="$1"
    local id="$2"

    jq -e \
      --arg type "${type}" \
      --arg id "${id}" \
      '
      any(
        .objects[];
        .type == $type
        and
        .id == $id
        and
        .status == "MATCH"
      )
      ' "${INVENTORY}" >/dev/null
}


# ============================================================
# DELETE HELPER
# ============================================================

delete_object() {

    local label="$1"
    local type="$2"
    local id="$3"
    local path="$4"
    local state_file="$5"

    if [[ -z "${id}" ]]; then

        fail "${label}" "STATE ID MISSING"
        return 1
    fi


    if ! approved "${type}" "${id}"; then

        fail "${label}" "NOT APPROVED BY INVENTORY"
        return 1
    fi


    if [[ "${MODE}" == "DRY_RUN" ]]; then

        printf "${YELLOW}[DRY]  ${RESET} %-31s WOULD DELETE\n" "${label}"
        printf '       ID: %s\n' "${id}"
        printf '       DELETE %s\n' "${path}"

        return 0
    fi


    TMP=$(mktemp)

    HTTP=$(
      curl -skS \
        -o "${TMP}" \
        -w '%{http_code}' \
        -X DELETE \
        -H "Authorization: apiToken ${INSTANA_TOKEN}" \
        -H "Accept: application/json" \
        "${INSTANA_URL}${path}"
    )


    if [[ "${HTTP}" =~ ^2[0-9][0-9]$ ]]; then

        ok "${label}" "DELETED / HTTP ${HTTP}"

        rm -f "${STATE_DIR}/${state_file}"
        rm -f "${TMP}"

        return 0

    else

        fail "${label}" "HTTP ${HTTP}"

        if [[ -s "${TMP}" ]]; then
            echo "       Backend response:"
            sed 's/^/       /' "${TMP}"
        fi

        rm -f "${TMP}"

        return 1
    fi
}


echo
echo "========================================================"
echo " INSTANA RETAIL LAB - CONTROLLED CLEANUP"
echo "========================================================"
echo

if [[ "${MODE}" == "DRY_RUN" ]]; then

    printf "${YELLOW}${BOLD}MODE: DRY RUN - NO DELETE WILL BE EXECUTED${RESET}\n"

else

    printf "${RED}${BOLD}MODE: EXECUTE - OBJECTS WILL BE DELETED${RESET}\n"

fi


# ============================================================
# LOCATION
# ============================================================

section "Preserved resource"

ok "Synthetic Location" "PRESERVED"
echo "       ID: ${LOCATION_ID}"
echo "       El PoP se limpiará posteriormente de forma coordinada."


# ============================================================
# DASHBOARD
# ============================================================

section "Cleanup plan"

ERRORS=0

delete_object \
  "Custom Dashboard" \
  "Custom Dashboard" \
  "${DASHBOARD_ID}" \
  "/api/custom-dashboard/${DASHBOARD_ID}" \
  "dashboard-id" \
  || ERRORS=$((ERRORS + 1))


# ============================================================
# SLO
# ============================================================

delete_object \
  "Technical SLO" \
  "Technical SLO" \
  "${SLO_TECH_ID}" \
  "/api/settings/slo/${SLO_TECH_ID}" \
  "slo-technical-id" \
  || ERRORS=$((ERRORS + 1))


delete_object \
  "Business SLO" \
  "Business SLO" \
  "${SLO_BUSINESS_ID}" \
  "/api/settings/slo/${SLO_BUSINESS_ID}" \
  "slo-business-id" \
  || ERRORS=$((ERRORS + 1))


# ============================================================
# ALERT
# ============================================================

delete_object \
  "Synthetic Smart Alert" \
  "Synthetic Smart Alert" \
  "${ALERT_ID}" \
  "/api/events/settings/global-alert-configs/synthetics/${ALERT_ID}" \
  "synthetic-business-alert-id" \
  || ERRORS=$((ERRORS + 1))


# ============================================================
# SYNTHETIC TESTS
# ============================================================

delete_object \
  "Synthetic Technical" \
  "Synthetic Technical" \
  "${SYNTH_TECH_ID}" \
  "/api/synthetics/settings/tests/${SYNTH_TECH_ID}" \
  "synthetic-technical-id" \
  || ERRORS=$((ERRORS + 1))


delete_object \
  "Synthetic Business" \
  "Synthetic Business" \
  "${SYNTH_BUSINESS_ID}" \
  "/api/synthetics/settings/tests/${SYNTH_BUSINESS_ID}" \
  "synthetic-business-id" \
  || ERRORS=$((ERRORS + 1))


# ============================================================
# APPLICATION
# ============================================================

delete_object \
  "Application Perspective" \
  "Application Perspective" \
  "${APPLICATION_ID}" \
  "/api/application-monitoring/settings/application/${APPLICATION_ID}" \
  "application-id" \
  || ERRORS=$((ERRORS + 1))


# ============================================================
# RESULT
# ============================================================

echo
echo "========================================================"

if [[ "${MODE}" == "DRY_RUN" ]]; then

    if (( ERRORS == 0 )); then

        printf "${GREEN}${BOLD} CLEANUP DRY RUN = READY${RESET}\n"

    else

        printf "${RED}${BOLD} CLEANUP DRY RUN = FAILED${RESET}\n"

    fi

else

    if (( ERRORS == 0 )); then

        printf "${GREEN}${BOLD} LOGICAL CLEANUP = COMPLETE${RESET}\n"

    else

        printf "${RED}${BOLD} LOGICAL CLEANUP = INCOMPLETE${RESET}\n"

    fi

fi

echo "========================================================"

echo
echo "Errors              : ${ERRORS}"
echo "Synthetic Location  : PRESERVED"

if [[ "${MODE}" == "DRY_RUN" && "${ERRORS}" == "0" ]]; then

    echo
    echo "No object was modified."
    echo
    echo "Para ejecutar realmente:"
    echo "  ./15-cleanup-instana.sh --execute"

fi

echo

exit "${ERRORS}"

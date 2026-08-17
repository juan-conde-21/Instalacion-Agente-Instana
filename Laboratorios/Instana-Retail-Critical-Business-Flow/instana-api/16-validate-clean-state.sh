#!/usr/bin/env bash
set -uo pipefail

BASE_DIR="/opt/instana-demo"
API_DIR="${BASE_DIR}/instana-api"
CONFIG_DIR="${API_DIR}/config"
STATE_DIR="${API_DIR}/state"

INVENTORY="${CONFIG_DIR}/cleanup-inventory.json"

source "${API_DIR}/00-load-runtime-env.sh"

SSH_KEY="/home/admin/.ssh/id_rsa"
SSH_USER="jammer"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

FAILURES=0

ok() {
    printf "${GREEN}[OK]   ${RESET} %-31s %s\n" "$1" "${2:-}"
}

fail() {
    printf "${RED}[FAIL] ${RESET} %-31s %s\n" "$1" "${2:-}"
    FAILURES=$((FAILURES + 1))
}

warn() {
    printf "${YELLOW}[WARN] ${RESET} %-31s %s\n" "$1" "${2:-}"
}

section() {
    echo
    printf "${BOLD}${CYAN}%s${RESET}\n" "$1"
}

SSH_OPTS=(
    -i "${SSH_KEY}"
    -o IdentitiesOnly=yes
    -o BatchMode=yes
    -o ConnectTimeout=8
    -o StrictHostKeyChecking=accept-new
)

remote() {
    ssh "${SSH_OPTS[@]}" \
        "${SSH_USER}@$1" \
        "${@:2}"
}


# ============================================================
# INVENTORY
# ============================================================

if [[ ! -s "${INVENTORY}" ]]; then
    echo "ERROR: cleanup inventory no encontrado."
    exit 1
fi

inventory_id() {
    local type="$1"

    jq -r \
      --arg type "${type}" \
      '
      first(
        .objects[] |
        select(.type == $type)
      ).id // empty
      ' "${INVENTORY}"
}


APPLICATION_ID=$(inventory_id "Application Perspective")

LOCATION_ID=$(inventory_id "Synthetic Location")

SYNTH_TECH_ID=$(inventory_id "Synthetic Technical")
SYNTH_BUSINESS_ID=$(inventory_id "Synthetic Business")

ALERT_ID=$(inventory_id "Synthetic Smart Alert")

SLO_TECH_ID=$(inventory_id "Technical SLO")
SLO_BUSINESS_ID=$(inventory_id "Business SLO")

DASHBOARD_ID=$(inventory_id "Custom Dashboard")


# ============================================================
# API HELPERS
# ============================================================

api_get() {
    local path="$1"
    local output="$2"

    curl -skS \
      -o "${output}" \
      -w '%{http_code}' \
      -H "Authorization: apiToken ${INSTANA_TOKEN}" \
      -H "Accept: application/json" \
      "${INSTANA_URL}${path}"
}


collection_contains() {
    local file="$1"
    local id="$2"

    jq -e \
      --arg id "${id}" \
      '
      def entries:
        if type == "array" then
          .[]
        elif
          type == "object"
          and
          ((.items? // null) | type) == "array"
        then
          .items[]
        else
          empty
        end;

      any(
        entries;
        (.id // "") == $id
      )
      ' "${file}" >/dev/null 2>&1
}


check_absent_collection() {
    local label="$1"
    local id="$2"
    local path="$3"

    local tmp
    local http

    tmp=$(mktemp)

    http=$(api_get "${path}" "${tmp}")

    if [[ "${http}" != "200" ]]; then
        fail "${label}" "LIST HTTP ${http}"
        rm -f "${tmp}"
        return
    fi

    if collection_contains "${tmp}" "${id}"; then
        fail "${label}" "STILL PRESENT"
    else
        ok "${label}" "ABSENT"
    fi

    rm -f "${tmp}"
}


check_absent_direct() {
    local label="$1"
    local id="$2"
    local path="$3"

    local tmp
    local http

    tmp=$(mktemp)

    http=$(api_get "${path}" "${tmp}")

    case "${http}" in
        404|410)
            ok "${label}" "ABSENT / HTTP ${http}"
            ;;
        200)
            fail "${label}" "STILL PRESENT"
            ;;
        *)
            fail "${label}" "UNEXPECTED HTTP ${http}"
            ;;
    esac

    rm -f "${tmp}"
}


echo
echo "========================================================"
echo " INSTANA RETAIL LAB - CLEAN STATE VALIDATION"
echo "========================================================"


# ============================================================
# APPLICATION
# ============================================================

section "Logical objects"

check_absent_collection \
  "Application Perspective" \
  "${APPLICATION_ID}" \
  "/api/application-monitoring/settings/application"


# ============================================================
# SYNTHETIC TESTS
# ============================================================

check_absent_direct \
  "Synthetic Technical" \
  "${SYNTH_TECH_ID}" \
  "/api/synthetics/settings/tests/${SYNTH_TECH_ID}"


check_absent_direct \
  "Synthetic Business" \
  "${SYNTH_BUSINESS_ID}" \
  "/api/synthetics/settings/tests/${SYNTH_BUSINESS_ID}"


# ============================================================
# ALERT
# ============================================================

check_absent_collection \
  "Synthetic Smart Alert" \
  "${ALERT_ID}" \
  "/api/events/settings/global-alert-configs/synthetics"


# ============================================================
# SLO
# ============================================================

check_absent_collection \
  "Technical SLO" \
  "${SLO_TECH_ID}" \
  "/api/settings/slo"


check_absent_collection \
  "Business SLO" \
  "${SLO_BUSINESS_ID}" \
  "/api/settings/slo"


# ============================================================
# DASHBOARD
# ============================================================

check_absent_collection \
  "Custom Dashboard" \
  "${DASHBOARD_ID}" \
  "/api/custom-dashboard?query=RETAIL&page=1&pageSize=100&withTotalHits=true"


# ============================================================
# SYNTHETIC LOCATION
# ============================================================

section "Preserved Synthetic PoP"

TMP=$(mktemp)

HTTP=$(
    api_get \
      "/api/synthetics/settings/locations" \
      "${TMP}"
)

if [[ "${HTTP}" == "200" ]]; then

    if collection_contains "${TMP}" "${LOCATION_ID}"; then

        ok "Synthetic Location" "PRESENT"
        printf '       ID: %s\n' "${LOCATION_ID}"

    else

        fail "Synthetic Location" "NOT FOUND"
    fi

else

    fail "Synthetic Location API" "HTTP ${HTTP}"
fi

rm -f "${TMP}"


# ============================================================
# POP KUBERNETES
# ============================================================

POP_RUNNING=$(
    remote demo-apps \
      'sudo -n k3s kubectl get pods \
         -n instana-synthetic \
         --field-selector=status.phase=Running \
         --no-headers 2>/dev/null |
       wc -l' \
      2>/dev/null |
    tr -d '[:space:]'
)

POP_RUNNING="${POP_RUNNING:-0}"

if [[ "${POP_RUNNING}" =~ ^[0-9]+$ ]] \
   && (( POP_RUNNING > 0 ))
then

    ok "Synthetic PoP workloads" \
       "${POP_RUNNING} running"

else

    fail "Synthetic PoP workloads" \
         "NONE RUNNING"
fi


# ============================================================
# STATE FILES
# ============================================================

section "Local state"

DELETED_STATE_FILES=(
    application-id
    synthetic-technical-id
    synthetic-business-id
    synthetic-business-alert-id
    slo-technical-id
    slo-business-id
    dashboard-id
)

for f in "${DELETED_STATE_FILES[@]}"
do

    if [[ ! -e "${STATE_DIR}/${f}" ]]; then
        ok "state/${f}" "REMOVED"
    else
        fail "state/${f}" "STILL PRESENT"
    fi

done


if [[ -s "${STATE_DIR}/synthetic-location-id" ]]; then

    CURRENT_LOCATION_ID=$(
        tr -d '\r\n' \
          < "${STATE_DIR}/synthetic-location-id"
    )

    if [[ "${CURRENT_LOCATION_ID}" == "${LOCATION_ID}" ]]; then
        ok "state/synthetic-location-id" "PRESERVED"
    else
        fail "state/synthetic-location-id" "ID MISMATCH"
    fi

else

    fail "state/synthetic-location-id" "MISSING"
fi


# ============================================================
# RESULT
# ============================================================

echo
echo "========================================================"

if (( FAILURES == 0 )); then

    printf "${GREEN}${BOLD} CLEAN STATE = VERIFIED${RESET}\n"

else

    printf "${RED}${BOLD} CLEAN STATE = FAILED${RESET}\n"

fi

echo "========================================================"

echo
echo "Failures : ${FAILURES}"

if (( FAILURES == 0 )); then

    echo
    echo "7 logical objects removed."
    echo "Synthetic Location / PoP preserved."
    echo
    echo "Environment is ready for logical rebuild."

fi

echo

exit "${FAILURES}"

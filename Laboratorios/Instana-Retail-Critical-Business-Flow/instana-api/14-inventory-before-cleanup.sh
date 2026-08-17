#!/usr/bin/env bash
set -uo pipefail

BASE_DIR="/opt/instana-demo"
API_DIR="${BASE_DIR}/instana-api"
STATE_DIR="${API_DIR}/state"
CONFIG_DIR="${API_DIR}/config"

mkdir -p "${CONFIG_DIR}"

source "${API_DIR}/00-load-runtime-env.sh"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

MATCHES=0
UNKNOWN=0
MISMATCH=0

TMPDIR=$(mktemp -d)
RECORDS="${TMPDIR}/records.jsonl"

trap 'rm -rf "${TMPDIR}"' EXIT

ok() {
    printf "${GREEN}[OK]   ${RESET} %-30s %s\n" "$1" "${2:-}"
}

fail() {
    printf "${RED}[FAIL] ${RESET} %-30s %s\n" "$1" "${2:-}"
}

warn() {
    printf "${YELLOW}[WARN] ${RESET} %-30s %s\n" "$1" "${2:-}"
}

section() {
    echo
    printf "${BOLD}${CYAN}%s${RESET}\n" "$1"
}


# ============================================================
# EXPECTED LAB OBJECTS
# ============================================================

EXPECTED_APPLICATION="RETAIL - Critical Promotions Flow"

EXPECTED_LOCATION="instana-critical-demo-pop"

EXPECTED_SYNTH_TECH="RETAIL - Technical Availability"
EXPECTED_SYNTH_BUSINESS="RETAIL - Business Transaction"

EXPECTED_ALERT="RETAIL - Business Transaction Failed"

EXPECTED_SLO_TECH="RETAIL - Technical Availability"
EXPECTED_SLO_BUSINESS="RETAIL - Business Availability"

EXPECTED_DASHBOARD="RETAIL - Critical Business Flow"


# ============================================================
# STATE
# ============================================================

read_state() {

    local name="$1"
    local file="${STATE_DIR}/${name}"

    if [[ -s "${file}" ]]; then
        tr -d '\r\n' < "${file}"
    fi
}


APPLICATION_ID=$(read_state application-id)
LOCATION_ID=$(read_state synthetic-location-id)

SYNTH_TECH_ID=$(read_state synthetic-technical-id)
SYNTH_BUSINESS_ID=$(read_state synthetic-business-id)

ALERT_ID=$(read_state synthetic-business-alert-id)

SLO_TECH_ID=$(read_state slo-technical-id)
SLO_BUSINESS_ID=$(read_state slo-business-id)

DASHBOARD_ID=$(read_state dashboard-id)


# ============================================================
# API
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


# ============================================================
# NORMALIZE COLLECTION
# ============================================================

find_object() {

    local file="$1"
    local id="$2"

    jq -c \
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

      first(
        entries |
        select((.id // "") == $id)
      ) // empty
      ' "${file}"
}


object_name() {

    jq -r '
      [
        .label?,
        .name?,
        .title?,
        .displayName?
      ]
      |
      map(
        select(
          type == "string"
          and
          length > 0
        )
      )
      |
      .[0] // "UNKNOWN"
    '
}


record_result() {

    local type="$1"
    local id="$2"
    local actual="$3"
    local expected="$4"
    local status="$5"

    jq -cn \
      --arg type "${type}" \
      --arg id "${id}" \
      --arg name "${actual}" \
      --arg expected "${expected}" \
      --arg status "${status}" \
      '{
        type: $type,
        id: $id,
        name: $name,
        expectedName: $expected,
        status: $status
      }' >> "${RECORDS}"
}


# ============================================================
# CHECK COLLECTION OBJECT
# ============================================================

check_collection() {

    local type="$1"
    local expected="$2"
    local id="$3"
    local file="$4"

    if [[ -z "${id}" ]]; then

        fail "${type}" "STATE ID MISSING"

        UNKNOWN=$((UNKNOWN + 1))

        record_result \
          "${type}" \
          "" \
          "UNKNOWN" \
          "${expected}" \
          "MISSING_STATE"

        return
    fi


    local object

    object=$(find_object "${file}" "${id}")


    if [[ -z "${object}" ]]; then

        fail "${type}" "ID NOT FOUND"

        echo "       ID: ${id}"

        UNKNOWN=$((UNKNOWN + 1))

        record_result \
          "${type}" \
          "${id}" \
          "UNKNOWN" \
          "${expected}" \
          "NOT_FOUND"

        return
    fi


    local actual

    actual=$(
      printf '%s\n' "${object}" |
      object_name
    )


    if [[ "${actual}" == "${expected}" ]]; then

        ok "${type}" "MATCH"

        printf '       Name: %s\n' "${actual}"
        printf '       ID  : %s\n' "${id}"

        MATCHES=$((MATCHES + 1))

        record_result \
          "${type}" \
          "${id}" \
          "${actual}" \
          "${expected}" \
          "MATCH"

    else

        fail "${type}" "NAME MISMATCH"

        printf '       Expected: %s\n' "${expected}"
        printf '       Actual  : %s\n' "${actual}"
        printf '       ID      : %s\n' "${id}"

        MISMATCH=$((MISMATCH + 1))

        record_result \
          "${type}" \
          "${id}" \
          "${actual}" \
          "${expected}" \
          "MISMATCH"
    fi
}


# ============================================================
# CHECK DIRECT OBJECT
# ============================================================

check_direct() {

    local type="$1"
    local expected="$2"
    local id="$3"
    local file="$4"

    if [[ -z "${id}" ]]; then

        fail "${type}" "STATE ID MISSING"
        UNKNOWN=$((UNKNOWN + 1))

        record_result \
          "${type}" \
          "" \
          "UNKNOWN" \
          "${expected}" \
          "MISSING_STATE"

        return
    fi


    local returned_id

    returned_id=$(
      jq -r '.id // empty' "${file}"
    )


    if [[ "${returned_id}" != "${id}" ]]; then

        fail "${type}" "ID NOT FOUND"

        UNKNOWN=$((UNKNOWN + 1))

        record_result \
          "${type}" \
          "${id}" \
          "UNKNOWN" \
          "${expected}" \
          "NOT_FOUND"

        return
    fi


    local actual

    actual=$(
      jq -c '.' "${file}" |
      object_name
    )


    if [[ "${actual}" == "${expected}" ]]; then

        ok "${type}" "MATCH"

        printf '       Name: %s\n' "${actual}"
        printf '       ID  : %s\n' "${id}"

        MATCHES=$((MATCHES + 1))

        record_result \
          "${type}" \
          "${id}" \
          "${actual}" \
          "${expected}" \
          "MATCH"

    else

        fail "${type}" "NAME MISMATCH"

        printf '       Expected: %s\n' "${expected}"
        printf '       Actual  : %s\n' "${actual}"
        printf '       ID      : %s\n' "${id}"

        MISMATCH=$((MISMATCH + 1))

        record_result \
          "${type}" \
          "${id}" \
          "${actual}" \
          "${expected}" \
          "MISMATCH"
    fi
}


echo
echo "========================================================"
echo " INSTANA RETAIL LAB - CLEANUP INVENTORY"
echo "========================================================"


# ============================================================
# LOAD APPLICATIONS
# ============================================================

section "Application Perspective"

HTTP=$(
  api_get \
    "/api/application-monitoring/settings/application" \
    "${TMPDIR}/applications.json"
)

if [[ "${HTTP}" == "200" ]]; then

    check_collection \
      "Application Perspective" \
      "${EXPECTED_APPLICATION}" \
      "${APPLICATION_ID}" \
      "${TMPDIR}/applications.json"

else

    fail "Application API" "HTTP ${HTTP}"
    UNKNOWN=$((UNKNOWN + 1))
fi


# ============================================================
# LOAD SYNTHETIC LOCATIONS
# ============================================================

section "Synthetic Location"

HTTP=$(
  api_get \
    "/api/synthetics/settings/locations" \
    "${TMPDIR}/locations.json"
)

if [[ "${HTTP}" == "200" ]]; then

    check_collection \
      "Synthetic Location" \
      "${EXPECTED_LOCATION}" \
      "${LOCATION_ID}" \
      "${TMPDIR}/locations.json"

else

    fail "Synthetic Location API" "HTTP ${HTTP}"
    UNKNOWN=$((UNKNOWN + 1))
fi


# ============================================================
# LOAD SYNTHETIC TESTS
# ============================================================

section "Synthetic Tests"

HTTP=$(
  api_get \
    "/api/synthetics/settings/tests" \
    "${TMPDIR}/tests.json"
)

if [[ "${HTTP}" == "200" ]]; then

    check_collection \
      "Synthetic Technical" \
      "${EXPECTED_SYNTH_TECH}" \
      "${SYNTH_TECH_ID}" \
      "${TMPDIR}/tests.json"

    check_collection \
      "Synthetic Business" \
      "${EXPECTED_SYNTH_BUSINESS}" \
      "${SYNTH_BUSINESS_ID}" \
      "${TMPDIR}/tests.json"

else

    fail "Synthetic Tests API" "HTTP ${HTTP}"
    UNKNOWN=$((UNKNOWN + 2))
fi


# ============================================================
# LOAD SYNTHETIC ALERTS
# ============================================================

section "Synthetic Smart Alert"

HTTP=$(
  api_get \
    "/api/events/settings/global-alert-configs/synthetics" \
    "${TMPDIR}/alerts.json"
)

if [[ "${HTTP}" == "200" ]]; then

    check_collection \
      "Synthetic Smart Alert" \
      "${EXPECTED_ALERT}" \
      "${ALERT_ID}" \
      "${TMPDIR}/alerts.json"

else

    fail "Synthetic Alert API" "HTTP ${HTTP}"
    UNKNOWN=$((UNKNOWN + 1))
fi


# ============================================================
# LOAD SLO
# ============================================================

section "Service Level Objectives"

HTTP=$(
  api_get \
    "/api/settings/slo" \
    "${TMPDIR}/slos.json"
)

if [[ "${HTTP}" == "200" ]]; then

    check_collection \
      "Technical SLO" \
      "${EXPECTED_SLO_TECH}" \
      "${SLO_TECH_ID}" \
      "${TMPDIR}/slos.json"

    check_collection \
      "Business SLO" \
      "${EXPECTED_SLO_BUSINESS}" \
      "${SLO_BUSINESS_ID}" \
      "${TMPDIR}/slos.json"

else

    fail "SLO API" "HTTP ${HTTP}"
    UNKNOWN=$((UNKNOWN + 2))
fi


# ============================================================
# LOAD DASHBOARD
# ============================================================

section "Custom Dashboard"

HTTP=$(
  api_get \
    "/api/custom-dashboard/${DASHBOARD_ID}" \
    "${TMPDIR}/dashboard.json"
)

if [[ "${HTTP}" == "200" ]]; then

    check_direct \
      "Custom Dashboard" \
      "${EXPECTED_DASHBOARD}" \
      "${DASHBOARD_ID}" \
      "${TMPDIR}/dashboard.json"

else

    fail "Custom Dashboard API" "HTTP ${HTTP}"
    UNKNOWN=$((UNKNOWN + 1))
fi


# ============================================================
# SAVE INVENTORY
# ============================================================

READY=false

if (( MATCHES == 8 \
   && UNKNOWN == 0 \
   && MISMATCH == 0 )); then

    READY=true
fi


if [[ -s "${RECORDS}" ]]; then

    jq -s \
      --arg generated "$(date -Is)" \
      --argjson ready "${READY}" \
      '
      {
        generatedAt: $generated,
        readyForCleanup: $ready,
        objects: .
      }
      ' \
      "${RECORDS}" \
      > "${CONFIG_DIR}/cleanup-inventory.json"

else

    jq -n \
      --arg generated "$(date -Is)" \
      '
      {
        generatedAt: $generated,
        readyForCleanup: false,
        objects: []
      }
      ' \
      > "${CONFIG_DIR}/cleanup-inventory.json"
fi


# ============================================================
# RESULT
# ============================================================

echo
echo "--------------------------------------------------------"
printf 'Objects recognized              : %s\n' "${MATCHES}"
printf 'Objects unknown                 : %s\n' "${UNKNOWN}"
printf 'Name mismatches                 : %s\n' "${MISMATCH}"
echo "--------------------------------------------------------"


if [[ "${READY}" == "true" ]]; then

    printf "${GREEN}${BOLD}READY FOR CONTROLLED CLEANUP    : YES${RESET}\n"

else

    printf "${RED}${BOLD}READY FOR CONTROLLED CLEANUP    : NO${RESET}\n"

fi


echo
echo "Inventory:"
echo "  ${CONFIG_DIR}/cleanup-inventory.json"

echo
echo "No object was modified or deleted."
echo


if [[ "${READY}" == "true" ]]; then
    exit 0
else
    exit 1
fi

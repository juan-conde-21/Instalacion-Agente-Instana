#!/usr/bin/env bash
set -uo pipefail

BASE_DIR="/opt/instana-demo"
API_DIR="${BASE_DIR}/instana-api"
STATE_DIR="${API_DIR}/state"
LOG_ROOT="${API_DIR}/logs"

STAMP=$(date +%Y%m%d-%H%M%S)
RUN_LOG_DIR="${LOG_ROOT}/rebuild-${STAMP}"

mkdir -p "${RUN_LOG_DIR}"

source "${API_DIR}/00-load-runtime-env.sh"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

FAILURES=0

ok() {
    printf "${GREEN}[OK]   ${RESET} %-32s %s\n" "$1" "${2:-}"
}

fail() {
    printf "${RED}[FAIL] ${RESET} %-32s %s\n" "$1" "${2:-}"
    FAILURES=$((FAILURES + 1))
}

info() {
    printf "${CYAN}[INFO] ${RESET} %-32s %s\n" "$1" "${2:-}"
}

state_value() {
    local file="$1"

    if [[ -s "${STATE_DIR}/${file}" ]]; then
        tr -d '\r\n' < "${STATE_DIR}/${file}"
    fi
}


# ============================================================
# EXECUTE COMPONENT
# ============================================================

run_step() {

    local label="$1"
    local script="$2"
    local log="${RUN_LOG_DIR}/${script%.sh}.log"

    if [[ ! -x "${API_DIR}/${script}" ]]; then
        fail "${label}" "SCRIPT MISSING"
        return 1
    fi

    if "${API_DIR}/${script}" \
        >"${log}" 2>&1
    then

        ok "${label}" "READY"
        return 0

    else

        fail "${label}" "FAILED"
        echo "       Log: ${log}"

        tail -20 "${log}" \
          | sed 's/^/       /'

        return 1
    fi
}


# ============================================================
# API GET
# ============================================================

api_get() {

    local path="$1"
    local file="$2"

    curl -skS \
      -o "${file}" \
      -w '%{http_code}' \
      -H "Authorization: apiToken ${INSTANA_TOKEN}" \
      -H "Accept: application/json" \
      "${INSTANA_URL}${path}"
}


echo
echo "========================================================"
echo " INSTANA RETAIL LAB - LOGICAL REBUILD"
echo "========================================================"
echo


# ============================================================
# PRECHECK
# ============================================================

info "Precheck" "RUNNING"

PRECHECK_LOG="${RUN_LOG_DIR}/13-precheck-all.log"

if "${API_DIR}/13-precheck-all.sh" \
    >"${PRECHECK_LOG}" 2>&1
then

    ok "Precheck" "READY"

else

    fail "Precheck" "FAILED"
    echo "       Log: ${PRECHECK_LOG}"

    tail -20 "${PRECHECK_LOG}" \
      | sed 's/^/       /'

    echo
    echo "REBUILD ABORTED"
    exit 1
fi


# ============================================================
# BUILD
# ============================================================

echo

run_step \
    "Application Perspective" \
    "01-create-application.sh" \
    || exit 1


run_step \
    "Synthetic Tests" \
    "02-sync-synthetics.sh" \
    || exit 1


run_step \
    "Synthetic Smart Alert" \
    "03-create-synthetic-alert.sh" \
    || exit 1


run_step \
    "Business SLO" \
    "04-create-slo.sh" \
    || exit 1


run_step \
    "Technical SLO" \
    "04b-create-technical-slo.sh" \
    || exit 1


run_step \
    "Custom Dashboard" \
    "05-create-dashboard.sh" \
    || exit 1


# ============================================================
# RESOLVE FINAL IDS
# ============================================================

APP_ID=$(state_value application-id)

LOCATION_ID=$(state_value synthetic-location-id)

TECH_ID=$(state_value synthetic-technical-id)
BUS_ID=$(state_value synthetic-business-id)

ALERT_ID=$(state_value synthetic-business-alert-id)

TECH_SLO_ID=$(state_value slo-technical-id)
BUS_SLO_ID=$(state_value slo-business-id)

DASH_ID=$(state_value dashboard-id)


echo
printf "${BOLD}${CYAN}Final validation${RESET}\n"


# ============================================================
# APPLICATION
# ============================================================

TMP=$(mktemp)

HTTP=$(
    api_get \
      "/api/application-monitoring/settings/application/${APP_ID}" \
      "${TMP}"
)

if [[ "${HTTP}" == "200" ]] \
   && jq -e \
      '.label == "RETAIL - Critical Promotions Flow"' \
      "${TMP}" >/dev/null
then

    ok "Application Perspective" "VALID"

else

    fail "Application Perspective" "INVALID / HTTP ${HTTP}"
fi

rm -f "${TMP}"


# ============================================================
# TECHNICAL SYNTHETIC
# ============================================================

TMP=$(mktemp)

HTTP=$(
    api_get \
      "/api/synthetics/settings/tests/${TECH_ID}" \
      "${TMP}"
)

if [[ "${HTTP}" == "200" ]] \
   && jq -e \
      --arg app "${APP_ID}" \
      '
      .label == "RETAIL - Technical Availability"
      and
      .active == true
      and
      .applicationId == $app
      and
      ((.locationLabels // []) | index("instana-critical-demo-pop") != null)
      ' "${TMP}" >/dev/null
then

    ok "Synthetic Technical" "VALID"

else

    fail "Synthetic Technical" "INVALID / HTTP ${HTTP}"
fi

rm -f "${TMP}"


# ============================================================
# BUSINESS SYNTHETIC
# ============================================================

TMP=$(mktemp)

HTTP=$(
    api_get \
      "/api/synthetics/settings/tests/${BUS_ID}" \
      "${TMP}"
)

if [[ "${HTTP}" == "200" ]] \
   && jq -e \
      --arg app "${APP_ID}" \
      '
      .label == "RETAIL - Business Transaction"
      and
      .active == true
      and
      .applicationId == $app
      and
      ((.locationLabels // []) | index("instana-critical-demo-pop") != null)
      ' "${TMP}" >/dev/null
then

    ok "Synthetic Business" "VALID"

else

    fail "Synthetic Business" "INVALID / HTTP ${HTTP}"
fi

rm -f "${TMP}"


# ============================================================
# SMART ALERT
# ============================================================

TMP=$(mktemp)

HTTP=$(
    api_get \
      "/api/events/settings/global-alert-configs/synthetics/${ALERT_ID}" \
      "${TMP}"
)

if [[ "${HTTP}" == "200" ]] \
   && jq -e \
      --arg bus "${BUS_ID}" \
      '
      .name == "RETAIL - Business Transaction Failed"
      and
      .severity == 10
      and
      ((.syntheticTestIds // []) | index($bus) != null)
      ' "${TMP}" >/dev/null
then

    ok "Synthetic Smart Alert" "VALID"

else

    fail "Synthetic Smart Alert" "INVALID / HTTP ${HTTP}"
fi

rm -f "${TMP}"


# ============================================================
# TECHNICAL SLO
# ============================================================

TMP=$(mktemp)

HTTP=$(
    api_get \
      "/api/settings/slo/${TECH_SLO_ID}" \
      "${TMP}"
)

if [[ "${HTTP}" == "200" ]] \
   && jq -e \
      --arg synth "${TECH_ID}" \
      '
      .name == "RETAIL - Technical Availability"
      and
      .target == 0.995
      and
      .entity.type == "synthetic"
      and
      ((.entity.syntheticTestIds // []) | index($synth) != null)
      and
      .indicator.type == "eventBased"
      and
      .indicator.blueprint == "availability"
      ' "${TMP}" >/dev/null
then

    ok "Technical SLO" "VALID"

else

    fail "Technical SLO" "INVALID / HTTP ${HTTP}"
fi

rm -f "${TMP}"


# ============================================================
# BUSINESS SLO
# ============================================================

TMP=$(mktemp)

HTTP=$(
    api_get \
      "/api/settings/slo/${BUS_SLO_ID}" \
      "${TMP}"
)

if [[ "${HTTP}" == "200" ]] \
   && jq -e \
      --arg synth "${BUS_ID}" \
      '
      .name == "RETAIL - Business Availability"
      and
      .target == 0.995
      and
      .entity.type == "synthetic"
      and
      ((.entity.syntheticTestIds // []) | index($synth) != null)
      and
      .indicator.type == "eventBased"
      and
      .indicator.blueprint == "availability"
      ' "${TMP}" >/dev/null
then

    ok "Business SLO" "VALID"

else

    fail "Business SLO" "INVALID / HTTP ${HTTP}"
fi

rm -f "${TMP}"


# ============================================================
# DASHBOARD
# ============================================================

TMP=$(mktemp)

HTTP=$(
    api_get \
      "/api/custom-dashboard/${DASH_ID}" \
      "${TMP}"
)

if [[ "${HTTP}" == "200" ]] \
   && jq -e \
      --arg tech "${TECH_SLO_ID}" \
      --arg bus "${BUS_SLO_ID}" \
      '
      .title == "RETAIL - Critical Business Flow"
      and
      ((.widgets // []) | length) == 6

      and

      (
        [
          .widgets[] |
          select(
            .type == "slo2"
            and
            .config.sloId == $tech
          )
        ]
        | length
      ) == 1

      and

      (
        [
          .widgets[] |
          select(
            .type == "slo2"
            and
            .config.sloId == $bus
          )
        ]
        | length
      ) == 2

      and

      (
        [
          .widgets[] |
          select(
            .type == "chart"
          )
        ]
        | length
      ) == 3
      ' "${TMP}" >/dev/null
then

    ok "Custom Dashboard" "VALID / 6 widgets"

else

    fail "Custom Dashboard" "INVALID / HTTP ${HTTP}"
fi

rm -f "${TMP}"


# ============================================================
# LOCATION
# ============================================================

if [[ -n "${LOCATION_ID}" ]]; then
    ok "Synthetic Location" "PRESERVED"
else
    fail "Synthetic Location" "STATE MISSING"
fi


# ============================================================
# RESULT
# ============================================================

echo
echo "========================================================"

if (( FAILURES == 0 )); then

    printf "${GREEN}${BOLD} INSTANA LOGICAL REBUILD = COMPLETE${RESET}\n"

else

    printf "${RED}${BOLD} INSTANA LOGICAL REBUILD = FAILED${RESET}\n"

fi

echo "========================================================"

echo
echo "Failures : ${FAILURES}"
echo
echo "Detailed logs:"
echo "  ${RUN_LOG_DIR}"
echo

if (( FAILURES == 0 )); then

    echo "Logical objects are ready."
    echo "Synthetic Location / PoP was preserved."
    echo
fi

exit "${FAILURES}"

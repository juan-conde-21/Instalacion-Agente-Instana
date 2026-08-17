#!/usr/bin/env bash
set -uo pipefail

BASE_DIR="/opt/instana-demo"
API_DIR="${BASE_DIR}/instana-api"
SECRETS_DIR="${BASE_DIR}/secrets"
GOLDEN_DIR="${BASE_DIR}/golden"

SSH_KEY="/home/admin/.ssh/id_rsa"
SSH_USER="jammer"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

FAILURES=0
WARNINGS=0

ok() {
    printf "${GREEN}[OK]   ${RESET} %-31s %s\n" "$1" "${2:-}"
}

fail() {
    printf "${RED}[FAIL] ${RESET} %-31s %s\n" "$1" "${2:-}"
    FAILURES=$((FAILURES + 1))
}

warn() {
    printf "${YELLOW}[WARN] ${RESET} %-31s %s\n" "$1" "${2:-}"
    WARNINGS=$((WARNINGS + 1))
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
    local host="$1"
    shift

    ssh "${SSH_OPTS[@]}" \
        "${SSH_USER}@${host}" \
        "$@"
}


echo
echo "========================================================"
echo " INSTANA RETAIL LAB - PRECHECK"
echo "========================================================"


# ============================================================
# 1. LOCAL REQUIREMENTS
# ============================================================

section "Bastion"

if [[ "$(id -u)" == "0" ]]; then
    ok "Execution user" "root"
else
    fail "Execution user" "root required"
fi


for CMD in \
    curl \
    jq \
    ssh \
    scp \
    tar \
    python3 \
    systemctl
do

    if command -v "${CMD}" >/dev/null 2>&1; then
        ok "Command ${CMD}" "AVAILABLE"
    else
        fail "Command ${CMD}" "MISSING"
    fi

done


if [[ -r "${SSH_KEY}" ]]; then

    MODE=$(stat -c '%a' "${SSH_KEY}" 2>/dev/null)

    if [[ "${MODE}" == "600" ]]; then
        ok "SSH key" "${SSH_KEY}"
    else
        fail "SSH key permissions" "${MODE} (expected 600)"
    fi

else

    fail "SSH key" "NOT AVAILABLE"

fi


# ============================================================
# 2. GOLDEN SNAPSHOT
# ============================================================

section "Golden State"

LATEST_GOLDEN=""

if [[ -d "${GOLDEN_DIR}" ]]; then

    LATEST_GOLDEN=$(
        find "${GOLDEN_DIR}" \
            -mindepth 1 \
            -maxdepth 1 \
            -type d \
            -printf '%f\n' 2>/dev/null |
        sort |
        tail -1
    )

fi


if [[ -n "${LATEST_GOLDEN}" ]]; then

    GOLDEN_PATH="${GOLDEN_DIR}/${LATEST_GOLDEN}"

    ok "Golden Snapshot" "${LATEST_GOLDEN}"

    if [[ -s "${GOLDEN_PATH}/SHA256SUMS" ]]; then

        if (
            cd "${GOLDEN_PATH}" &&
            sha256sum -c SHA256SUMS >/dev/null 2>&1
        ); then

            ok "Snapshot integrity" "VALID"

        else

            fail "Snapshot integrity" "CHECKSUM ERROR"

        fi

    else

        fail "Snapshot manifest" "MISSING"

    fi

else

    fail "Golden Snapshot" "NOT FOUND"

fi


# ============================================================
# 3. CREDENTIALS
# ============================================================

section "Credentials"

if source "${API_DIR}/00-load-runtime-env.sh" >/dev/null 2>&1; then

    ok "Runtime credentials" "LOADED"

else

    fail "Runtime credentials" "INVALID"
fi


if [[ -f "${SECRETS_DIR}/instana.token" ]]; then

    MODE=$(stat -c '%a' "${SECRETS_DIR}/instana.token")

    if [[ "${MODE}" == "600" ]]; then
        ok "Instana token permissions" "600"
    else
        fail "Instana token permissions" "${MODE}"
    fi

else

    fail "Instana token" "MISSING"

fi


if [[ -f "${SECRETS_DIR}/synthetic.env" ]]; then

    MODE=$(stat -c '%a' "${SECRETS_DIR}/synthetic.env")

    if [[ "${MODE}" == "600" ]]; then
        ok "Synthetic secret permissions" "600"
    else
        fail "Synthetic secret permissions" "${MODE}"
    fi

else

    fail "Synthetic credentials" "MISSING"

fi


for VAR in \
    SYNTHETIC_DOWNLOAD_KEY \
    SYNTHETIC_INSTANA_KEY \
    SYNTHETIC_ENDPOINT \
    SYNTHETIC_REDIS_PASSWORD
do

    if [[ -n "${!VAR:-}" ]]; then
        ok "${VAR}" "PRESENT"
    else
        fail "${VAR}" "MISSING"
    fi

done


if [[ "${SYNTHETIC_ENDPOINT:-}" =~ ^https:// ]]; then
    ok "Synthetic endpoint" "HTTPS"
else
    fail "Synthetic endpoint" "INVALID"
fi


# ============================================================
# 4. INSTANA API
# ============================================================

section "Instana"

api_check() {

    local label="$1"
    local path="$2"

    local tmp
    local http

    tmp=$(mktemp)

    http=$(
        curl -skS \
            -o "${tmp}" \
            -w '%{http_code}' \
            -H "Authorization: apiToken ${INSTANA_TOKEN}" \
            -H "Accept: application/json" \
            "${INSTANA_URL}${path}"
    )

    rm -f "${tmp}"

    if [[ "${http}" == "200" ]]; then
        ok "${label}" "HTTP 200"
    else
        fail "${label}" "HTTP ${http}"
    fi
}


api_check \
    "Instana API" \
    "/api/application-monitoring/catalog/metrics"


api_check \
    "SLO Configuration API" \
    "/api/settings/slo"


api_check \
    "Synthetic API" \
    "/api/synthetics/settings/locations"


api_check \
    "Custom Dashboard API" \
    "/api/custom-dashboard/shareable-users"


# ============================================================
# 5. BLUEBOX
# ============================================================

section "Bluebox"

if remote bluebox \
    'printf OK' \
    >/dev/null 2>&1
then

    ok "SSH bluebox" "jammer"

else

    fail "SSH bluebox"
fi


if remote bluebox \
    'sudo -n true' \
    >/dev/null 2>&1
then

    ok "sudo bluebox" "PASSWORDLESS"

else

    fail "sudo bluebox"
fi


if remote bluebox \
    'sudo -n systemctl is-active --quiet instana-agent.service || sudo -n systemctl is-active --quiet instana-agent' \
    >/dev/null 2>&1
then

    ok "Instana Agent bluebox" "ACTIVE"

else

    fail "Instana Agent bluebox" "NOT ACTIVE"
fi


if remote bluebox \
    'sudo -n test -d /opt/instana' \
    >/dev/null 2>&1
then

    ok "Instana installation" "/opt/instana"

else

    fail "Instana installation" "NOT FOUND"
fi


# ============================================================
# 6. DEMO APPS
# ============================================================

section "Demo Apps"

if remote demo-apps \
    'printf OK' \
    >/dev/null 2>&1
then

    ok "SSH demo-apps" "jammer"

else

    fail "SSH demo-apps"
fi


if remote demo-apps \
    'sudo -n true' \
    >/dev/null 2>&1
then

    ok "sudo demo-apps" "PASSWORDLESS"

else

    fail "sudo demo-apps"
fi


NODE_STATE=$(
    remote demo-apps \
        'sudo -n k3s kubectl get node demo-apps -o jsonpath="{.status.conditions[?(@.type==\"Ready\")].status}"' \
        2>/dev/null || true
)


if [[ "${NODE_STATE}" == "True" ]]; then

    ok "K3s node" "READY"

else

    fail "K3s node" "${NODE_STATE:-UNKNOWN}"
fi


if remote demo-apps \
    'sudo -n k3s kubectl auth can-i "*" "*" --all-namespaces 2>/dev/null | grep -qx yes' \
    >/dev/null 2>&1
then

    ok "Kubernetes privileges" "ADMIN"

else

    fail "Kubernetes privileges" "INSUFFICIENT"
fi


if remote demo-apps \
    'sudo -n k3s kubectl get namespace instana-agent >/dev/null 2>&1' \
    >/dev/null 2>&1
then

    ok "Instana namespace" "PRESENT"

else

    warn "Instana namespace" "NOT FOUND"
fi


RUNNING_INSTANA=$(
    remote demo-apps '
        sudo -n k3s kubectl get pods \
            -n instana-agent \
            --field-selector=status.phase=Running \
            --no-headers 2>/dev/null |
        wc -l
    ' 2>/dev/null |
    tr -d '[:space:]'
)

RUNNING_INSTANA="${RUNNING_INSTANA:-0}"


if [[ "${RUNNING_INSTANA}" =~ ^[0-9]+$ ]] \
   && (( RUNNING_INSTANA > 0 ))
then

    ok "Instana K8s workloads" \
       "${RUNNING_INSTANA} running"

else

    warn "Instana K8s workloads" "NONE DETECTED"
fi


# ============================================================
# 7. SYNTHETIC PREREQUISITES
# ============================================================

section "Synthetic PoP prerequisites"

if remote demo-apps \
    'command -v helm >/dev/null 2>&1' \
    >/dev/null 2>&1
then
    ok "Helm" "AVAILABLE"
else
    fail "Helm" "MISSING"
fi


if remote demo-apps \
    'sudo -n k3s kubectl version --client >/dev/null 2>&1' \
    >/dev/null 2>&1
then
    ok "kubectl / k3s" "AVAILABLE"
else
    fail "kubectl / k3s" "MISSING"
fi


# ============================================================
# RESULT
# ============================================================

echo
echo "========================================================"

if (( FAILURES == 0 )); then

    printf "${GREEN}${BOLD} PRECHECK = READY${RESET}\n"

else

    printf "${RED}${BOLD} PRECHECK = FAILED${RESET}\n"

fi

echo "========================================================"

echo
echo "Failures : ${FAILURES}"
echo "Warnings : ${WARNINGS}"

if (( FAILURES == 0 )); then

    echo
    echo "El ambiente cumple los prerrequisitos"
    echo "para limpieza y reconstrucción controlada."

else

    echo
    echo "No ejecutar cleanup ni rebuild"
    echo "hasta resolver los FAIL."

fi

echo

exit "${FAILURES}"

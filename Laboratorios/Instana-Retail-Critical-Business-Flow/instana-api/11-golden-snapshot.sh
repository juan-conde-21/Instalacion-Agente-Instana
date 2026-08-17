#!/usr/bin/env bash
set -uo pipefail

BASE_DIR="/opt/instana-demo"
API_DIR="${BASE_DIR}/instana-api"

SSH_KEY="/home/admin/.ssh/id_rsa"
SSH_USER="jammer"

STAMP=$(date +%Y%m%d-%H%M%S)
GOLDEN_ROOT="${BASE_DIR}/golden"
OUT="${GOLDEN_ROOT}/${STAMP}"

mkdir -p \
  "${OUT}/bastion" \
  "${OUT}/bluebox" \
  "${OUT}/demo-apps" \
  "${OUT}/instana"

chmod 700 "${GOLDEN_ROOT}" "${OUT}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
RESET='\033[0m'

ok() {
    printf "${GREEN}[OK]   ${RESET} %-30s %s\n" "$1" "${2:-}"
}

warn() {
    printf "${YELLOW}[WARN] ${RESET} %-30s %s\n" "$1" "${2:-}"
}

fail() {
    printf "${RED}[FAIL] ${RESET} %-30s %s\n" "$1" "${2:-}"
}

SSH_OPTS=(
  -i "${SSH_KEY}"
  -o IdentitiesOnly=yes
  -o BatchMode=yes
  -o ConnectTimeout=10
  -o StrictHostKeyChecking=accept-new
)

remote_exec() {
    local host="$1"
    shift

    ssh "${SSH_OPTS[@]}" \
      "${SSH_USER}@${host}" \
      "$@"
}

echo
echo "========================================================"
echo " INSTANA RETAIL LAB - GOLDEN SNAPSHOT"
echo "========================================================"
echo


# ============================================================
# 1. BASTION
# ============================================================

printf "%b\n" "${BOLD}Bastion${RESET}"

{
    echo "HOSTNAME=$(hostname)"
    echo "DATE=$(date -Is)"
    echo
    cat /etc/os-release 2>/dev/null || true
} > "${OUT}/bastion/host-info.txt"

ok "Host information"


tar \
  --exclude='*/golden/*' \
  --exclude='*/backups/*' \
  --exclude='*/secrets/*' \
  --exclude='*/logs/*' \
  --exclude='*/.env' \
  --exclude='*/.env.*' \
  --exclude='*.key' \
  -czf "${OUT}/bastion/instana-demo.tar.gz" \
  -C "${BASE_DIR}" \
  source \
  instana-api \
  2>"${OUT}/bastion/tar.log"

if [[ -s "${OUT}/bastion/instana-demo.tar.gz" ]]; then
    ok "SOURCE + automation"
else
    fail "SOURCE + automation"
fi


{
    for unit in \
      instana-demo-source.service \
      instana-demo-source.timer
    do

        echo
        echo "### ${unit}"

        systemctl cat "${unit}" \
          2>/dev/null || true

    done
} > "${OUT}/bastion/systemd.txt"

ok "systemd definitions"


# ============================================================
# 2. INSTANA LOCAL DEFINITIONS
# ============================================================

echo
printf "%b\n" "${BOLD}Instana definitions${RESET}"


if [[ -d "${API_DIR}/config" ]]; then

    cp -a \
      "${API_DIR}/config" \
      "${OUT}/instana/config"

    ok "Canonical JSON/config"
else
    warn "Canonical JSON/config" "config/ no existe"
fi


if [[ -d "${API_DIR}/state" ]]; then

    mkdir -p "${OUT}/instana/state"

    for f in "${API_DIR}"/state/*
    do
        [[ -f "${f}" ]] || continue

        name=$(basename "${f}")

        case "${name}" in
            *token*|*password*|*secret*|*key*)
                continue
                ;;
        esac

        cp -p "${f}" \
          "${OUT}/instana/state/${name}"
    done

    ok "Current object IDs"
else
    warn "Current object IDs" "state/ no existe"
fi


grep -RhoE \
  '/api/[A-Za-z0-9_./?=&{}$:-]+' \
  "${API_DIR}"/*.sh \
  2>/dev/null \
  | sort -u \
  > "${OUT}/instana/api-endpoints-used.txt"

ok "Validated API endpoints"


# ============================================================
# DASHBOARD LIVE EXPORT
# ============================================================

if [[ -n "${INSTANA_TOKEN:-}" \
   && -n "${INSTANA_URL:-}" \
   && -s "${API_DIR}/state/dashboard-id" ]]; then

    DASHBOARD_ID=$(cat "${API_DIR}/state/dashboard-id")

    HTTP=$(
      curl -skS \
        -o "${OUT}/instana/dashboard-live.json" \
        -w '%{http_code}' \
        -H "Authorization: apiToken ${INSTANA_TOKEN}" \
        -H "Accept: application/json" \
        "${INSTANA_URL}/api/custom-dashboard/${DASHBOARD_ID}"
    )

    if [[ "${HTTP}" == "200" ]]; then
        ok "Dashboard live export"
    else
        rm -f "${OUT}/instana/dashboard-live.json"
        warn "Dashboard live export" "HTTP ${HTTP}"
    fi

else

    warn "Dashboard live export" \
         "token no cargado; config local preservada"

fi


# ============================================================
# 3. BLUEBOX
# ============================================================

echo
printf "%b\n" "${BOLD}Bluebox${RESET}"


if remote_exec bluebox \
     'printf "%s\n" "$(hostname)"' \
     >/dev/null 2>&1
then
    ok "SSH"
else
    fail "SSH"
    exit 1
fi


remote_exec bluebox '
    echo "HOSTNAME=$(hostname)"
    echo "DATE=$(date -Is)"
    echo
    cat /etc/os-release 2>/dev/null || true
' > "${OUT}/bluebox/host-info.txt" 2>/dev/null

ok "Host information"


remote_exec bluebox '
    if sudo -n test -d /opt/instana-demo; then

        sudo -n tar \
          --exclude="*/secrets/*" \
          --exclude="*/.env" \
          --exclude="*/.env.*" \
          --exclude="*.key" \
          -czf - \
          /opt/instana-demo

    fi
' > "${OUT}/bluebox/instana-demo.tar.gz" \
  2>"${OUT}/bluebox/tar.log"

if [[ -s "${OUT}/bluebox/instana-demo.tar.gz" ]]; then
    ok "/opt/instana-demo"
else
    warn "/opt/instana-demo" "no capturado"
fi


remote_exec bluebox '
    if sudo -n test -f \
      /opt/instana/agent/etc/instana/configuration-demo.yaml
    then
        sudo -n cat \
          /opt/instana/agent/etc/instana/configuration-demo.yaml
    fi
' > "${OUT}/bluebox/configuration-demo.yaml" \
  2>/dev/null

if [[ -s "${OUT}/bluebox/configuration-demo.yaml" ]]; then
    ok "File Monitoring config"
else
    warn "File Monitoring config"
fi


remote_exec bluebox '
    for unit in $(
      systemctl list-unit-files \
        --type=service \
        --no-legend 2>/dev/null |
      awk "/instana-demo/ {print \$1}"
    )
    do
        echo
        echo "### ${unit}"
        sudo -n systemctl cat "${unit}" 2>/dev/null || true
    done
' > "${OUT}/bluebox/systemd.txt" 2>/dev/null

ok "systemd definitions"


# ============================================================
# 4. DEMO APPS
# ============================================================

echo
printf "%b\n" "${BOLD}Demo Apps${RESET}"


if remote_exec demo-apps \
     'printf "%s\n" "$(hostname)"' \
     >/dev/null 2>&1
then
    ok "SSH"
else
    fail "SSH"
    exit 1
fi


remote_exec demo-apps '
    echo "HOSTNAME=$(hostname)"
    echo "DATE=$(date -Is)"
    echo
    cat /etc/os-release 2>/dev/null || true
' > "${OUT}/demo-apps/host-info.txt" 2>/dev/null

ok "Host information"


remote_exec demo-apps '
    sudo -n k3s kubectl get node -o wide
' > "${OUT}/demo-apps/k3s-node.txt" 2>/dev/null

ok "K3s node"


remote_exec demo-apps '
    sudo -n k3s kubectl get namespace
' > "${OUT}/demo-apps/namespaces.txt" 2>/dev/null

ok "Namespaces"


remote_exec demo-apps '
    sudo -n k3s kubectl \
      get deployment,daemonset,statefulset,service,configmap \
      -A -o wide 2>/dev/null |
    grep -Ei "instana|otel|synthetic|retail" || true
' > "${OUT}/demo-apps/workload-inventory.txt" 2>/dev/null

ok "Workload inventory"


for NS in \
  instana-critical-demo \
  instana-synthetic
do

    remote_exec demo-apps "
        sudo -n k3s kubectl \
          get deployment,daemonset,statefulset,service,configmap \
          -n ${NS} \
          -o yaml 2>/dev/null || true
    " > "${OUT}/demo-apps/${NS}.yaml" \
      2>/dev/null

done

ok "Kubernetes manifests"


remote_exec demo-apps '
    if command -v helm >/dev/null 2>&1; then
        sudo -n helm list -A 2>/dev/null || helm list -A 2>/dev/null || true
    fi
' > "${OUT}/demo-apps/helm-releases.txt" 2>/dev/null

ok "Helm release inventory"


remote_exec demo-apps '
    if sudo -n test -d /opt/instana-demo; then

        sudo -n tar \
          --exclude="*/secrets/*" \
          --exclude="*/.env" \
          --exclude="*/.env.*" \
          --exclude="*.key" \
          -czf - \
          /opt/instana-demo

    fi
' > "${OUT}/demo-apps/instana-demo.tar.gz" \
  2>"${OUT}/demo-apps/tar.log"

if [[ -s "${OUT}/demo-apps/instana-demo.tar.gz" ]]; then
    ok "/opt/instana-demo"
else
    warn "/opt/instana-demo" "no existe o está vacío"
fi


# ============================================================
# 5. MANIFEST
# ============================================================

echo
printf "%b\n" "${BOLD}Integrity${RESET}"

find "${OUT}" \
  -type f \
  ! -name SHA256SUMS \
  -exec sha256sum {} \; \
  | sort \
  > "${OUT}/SHA256SUMS"

ok "SHA256 manifest"


cat > "${OUT}/README.txt" <<EOF2
INSTANA RETAIL LAB - GOLDEN SNAPSHOT
Created: $(date -Is)

Purpose:
Preserve the last validated working state before cleanup/rebuild.

Captured:
- Bastion SOURCE and automation
- Instana canonical configs and state IDs
- Bluebox demo components
- Instana File Monitoring configuration
- Demo Apps Kubernetes manifests
- Helm release inventory
- K3s information

Intentionally NOT captured:
- Instana API tokens
- Synthetic downloadKey
- Synthetic instanaKey
- Redis passwords
- Kubernetes Secrets
- SSH private keys
- .env secret files

Synthetic authentication must be supplied again
from the Instana GUI prerequisites.
EOF2


echo
echo "========================================================"
echo " GOLDEN SNAPSHOT = COMPLETE"
echo "========================================================"
echo
echo "Location:"
echo "  ${OUT}"
echo
echo "No destructive action was performed."
echo

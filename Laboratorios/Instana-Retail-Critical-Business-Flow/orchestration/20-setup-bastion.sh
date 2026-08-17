#!/usr/bin/env bash
set -uo pipefail

MODE="${1:-apply}"

BASE="/opt/instana-demo/source"
SCRIPT_DIR="${BASE}/scripts"
OUT_DIR="${BASE}/outbox"
LOG_DIR="${BASE}/logs"

RUN_JOB="${SCRIPT_DIR}/run-job.sh"
SOURCE_FILE="${OUT_DIR}/promotions_current.csv"
SOURCE_LOG="${LOG_DIR}/source-job.log"

SERVICE="/etc/systemd/system/instana-demo-source.service"
TIMER="/etc/systemd/system/instana-demo-source.timer"

DEMO_USER="instanademo"
DEMO_GROUP="instanademo"

CENTRAL_URL="${CENTRAL_URL:-http://192.168.252.35:18082}"

FAILURES=0
WARNINGS=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'


ok() {
    printf "${GREEN}[OK]   ${RESET} %-30s %s\n" "$1" "${2:-}"
}

fail() {
    printf "${RED}[FAIL] ${RESET} %-30s %s\n" "$1" "${2:-}"
    FAILURES=$((FAILURES + 1))
}

warn() {
    printf "${YELLOW}[WARN] ${RESET} %-30s %s\n" "$1" "${2:-}"
    WARNINGS=$((WARNINGS + 1))
}

info() {
    printf "${CYAN}[INFO] ${RESET} %-30s %s\n" "$1" "${2:-}"
}


check_command() {
    if command -v "$1" >/dev/null 2>&1; then
        ok "Command $1" "AVAILABLE"
    else
        fail "Command $1" "MISSING"
    fi
}


validate_central() {

    local body
    local code

    body=$(mktemp)

    code=$(
        curl -sS \
          --connect-timeout 5 \
          --max-time 10 \
          -o "${body}" \
          -w '%{http_code}' \
          "${CENTRAL_URL}/health" \
          2>/dev/null || true
    )

    if [[ "${code}" == "200" ]]; then
        ok "CENTRAL health" "HTTP 200"
    else
        fail "CENTRAL health" "HTTP ${code:-UNREACHABLE}"
    fi

    rm -f "${body}"
}


validate_source_file() {

    if [[ ! -f "${SOURCE_FILE}" ]]; then
        fail "SOURCE CSV" "MISSING"
        return
    fi

    local lines
    local records
    local size

    lines=$(wc -l < "${SOURCE_FILE}")
    records=$((lines - 1))
    size=$(stat -c%s "${SOURCE_FILE}")

    if [[ "${records}" -eq 5000 ]]; then
        ok "SOURCE records" "5000"
    else
        fail "SOURCE records" "${records}"
    fi

    if [[ "${size}" -gt 150000 ]]; then
        ok "SOURCE file size" "${size} bytes"
    else
        fail "SOURCE file size" "${size} bytes"
    fi

    if head -1 "${SOURCE_FILE}" \
       | grep -qx \
       'sku,product_name,base_price,discount_pct,version'
    then
        ok "SOURCE CSV header" "VALID"
    else
        fail "SOURCE CSV header" "INVALID"
    fi
}


validate_runtime() {

    if [[ -x "${RUN_JOB}" ]]; then
        ok "SOURCE generator" "EXECUTABLE"
    else
        fail "SOURCE generator" "MISSING / NOT EXECUTABLE"
    fi

    validate_source_file

    if systemctl is-enabled \
         instana-demo-source.timer \
         >/dev/null 2>&1
    then
        ok "SOURCE timer" "ENABLED"
    else
        fail "SOURCE timer" "NOT ENABLED"
    fi

    if systemctl is-active \
         instana-demo-source.timer \
         >/dev/null 2>&1
    then
        ok "SOURCE timer" "ACTIVE"
    else
        fail "SOURCE timer" "NOT ACTIVE"
    fi

    local service_result

    service_result=$(
        systemctl show \
          instana-demo-source.service \
          -p Result \
          --value \
          2>/dev/null || true
    )

    if [[ "${service_result}" == "success" ]]; then
        ok "SOURCE last execution" "SUCCESS"
    else
        warn "SOURCE last execution" "${service_result:-UNKNOWN}"
    fi

    if [[ -f "${SOURCE_LOG}" ]] \
       && tail -50 "${SOURCE_LOG}" \
          | grep -q 'event=upload_success'
    then
        ok "SOURCE publication" "SUCCESS FOUND"
    else
        warn "SOURCE publication" "NO RECENT SUCCESS"
    fi
}


echo
echo "========================================================"
echo " INSTANA RETAIL LAB - BASTION SOURCE"
echo "========================================================"
echo


# ============================================================
# PRECHECK
# ============================================================

if [[ "${EUID}" -ne 0 ]]; then
    fail "Execution user" "ROOT REQUIRED"
else
    ok "Execution user" "ROOT"
fi

for cmd in \
    awk \
    curl \
    grep \
    head \
    stat \
    systemctl \
    wc
do
    check_command "${cmd}"
done


# ============================================================
# CHECK MODE
# ============================================================

if [[ "${MODE}" == "--check" ]]; then

    echo
    info "Mode" "READ ONLY"

    if getent passwd "${DEMO_USER}" >/dev/null 2>&1; then
        ok "User ${DEMO_USER}" "PRESENT"
    else
        fail "User ${DEMO_USER}" "MISSING"
    fi

    for dir in \
        "${BASE}" \
        "${SCRIPT_DIR}" \
        "${OUT_DIR}" \
        "${LOG_DIR}"
    do
        if [[ -d "${dir}" ]]; then
            ok "Directory" "${dir}"
        else
            fail "Directory" "${dir} MISSING"
        fi
    done

    if [[ -f "${SERVICE}" ]]; then
        ok "systemd service" "PRESENT"
    else
        fail "systemd service" "MISSING"
    fi

    if [[ -f "${TIMER}" ]]; then
        ok "systemd timer" "PRESENT"
    else
        fail "systemd timer" "MISSING"
    fi

    validate_central
    validate_runtime

    echo
    echo "========================================================"

    if (( FAILURES == 0 )); then
        echo " BASTION SOURCE CHECK = READY"
    else
        echo " BASTION SOURCE CHECK = FAILED"
    fi

    echo "========================================================"
    echo
    echo "Failures : ${FAILURES}"
    echo "Warnings : ${WARNINGS}"
    echo

    exit "${FAILURES}"
fi


# ============================================================
# APPLY MODE
# ============================================================

if [[ "${MODE}" != "apply" && "${MODE}" != "--apply" ]]; then
    echo "Usage:"
    echo "  $0 --check"
    echo "  $0"
    echo
    exit 2
fi

echo
info "Mode" "APPLY"


# ============================================================
# USER / GROUP
# ============================================================

if ! getent group "${DEMO_GROUP}" >/dev/null 2>&1; then
    groupadd --system "${DEMO_GROUP}"
fi

if ! getent passwd "${DEMO_USER}" >/dev/null 2>&1; then

    useradd \
      --system \
      --gid "${DEMO_GROUP}" \
      --home-dir "${BASE}" \
      --shell /sbin/nologin \
      "${DEMO_USER}"
fi

ok "Demo account" "${DEMO_USER}:${DEMO_GROUP}"


# ============================================================
# DIRECTORIES
# ============================================================

install \
  -d \
  -o "${DEMO_USER}" \
  -g "${DEMO_GROUP}" \
  -m 0755 \
  "${BASE}" \
  "${SCRIPT_DIR}" \
  "${OUT_DIR}" \
  "${LOG_DIR}"

touch "${SOURCE_LOG}"

chown \
  "${DEMO_USER}:${DEMO_GROUP}" \
  "${SOURCE_LOG}"

chmod 0644 "${SOURCE_LOG}"

ok "SOURCE directories" "READY"


# ============================================================
# GENERATOR
# ============================================================

cat > "${RUN_JOB}" <<'RUNJOB'
#!/usr/bin/env bash
set -euo pipefail

BASE="/opt/instana-demo/source"
OUT="${BASE}/outbox"
LOG="${BASE}/logs/source-job.log"

CENTRAL_URL="${CENTRAL_URL:-http://192.168.252.35:18082}"

VERSION="$(date -u +%Y%m%d-%H%M%S)"

TMP="${OUT}/promotions_current.csv.tmp"
FILE="${OUT}/promotions_current.csv"

log() {
  printf '%s %s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    "$*" >> "${LOG}"
}

cleanup() {
  rm -f "${TMP}" "${RESP:-}"
}

trap cleanup EXIT

log "level=INFO event=job_started version=${VERSION}"

{
  echo "sku,product_name,base_price,discount_pct,version"

  awk -v version="${VERSION}" '
  BEGIN {
    for (i=1; i<=5000; i++) {
      sku=sprintf("P%05d",i);
      price=50+(i%500);
      discount=5+(i%25);

      printf "%s,Producto_%05d,%0.2f,%d,%s\n",
             sku,i,price,discount,version;
    }
  }'
} > "${TMP}"

mv "${TMP}" "${FILE}"

SIZE="$(stat -c%s "${FILE}")"

log "level=INFO event=file_generated version=${VERSION} size_bytes=${SIZE}"

RESP="$(mktemp /tmp/instana-demo-source-response.XXXXXX)"

HTTP_CODE="$(
curl -sS \
  --connect-timeout 5 \
  --max-time 30 \
  -o "${RESP}" \
  -w '%{http_code}' \
  -X POST \
  -H "Content-Type: text/csv" \
  -H "X-Version: ${VERSION}" \
  --data-binary "@${FILE}" \
  "${CENTRAL_URL}/api/files/upload"
)"

if [[ "${HTTP_CODE}" =~ ^2 ]]; then

  log "level=INFO event=upload_success version=${VERSION} http_status=${HTTP_CODE}"

  cat "${RESP}"
  echo

else

  log "level=ERROR event=upload_failed version=${VERSION} http_status=${HTTP_CODE}"

  cat "${RESP}" >&2

  exit 1
fi

log "level=INFO event=job_completed version=${VERSION}"
RUNJOB

chown \
  "${DEMO_USER}:${DEMO_GROUP}" \
  "${RUN_JOB}"

chmod 0755 "${RUN_JOB}"

ok "SOURCE generator" "INSTALLED"


# ============================================================
# SYSTEMD SERVICE
# ============================================================

cat > "${SERVICE}" <<'SERVICEEOF'
[Unit]
Description=Instana Demo Promotion File Job
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=instanademo
Group=instanademo

ExecStart=/opt/instana-demo/source/scripts/run-job.sh
SERVICEEOF

chmod 0644 "${SERVICE}"

ok "systemd service" "INSTALLED"


# ============================================================
# SYSTEMD TIMER
# ============================================================

cat > "${TIMER}" <<'TIMEREOF'
[Unit]
Description=Run Instana Demo Promotion Job Every Minute

[Timer]
OnBootSec=15s
OnUnitActiveSec=60s
AccuracySec=5s
Unit=instana-demo-source.service

[Install]
WantedBy=timers.target
TIMEREOF

chmod 0644 "${TIMER}"

ok "systemd timer" "INSTALLED"


# ============================================================
# SYSTEMD ACTIVATE
# ============================================================

systemctl daemon-reload

systemctl enable \
  instana-demo-source.timer \
  >/dev/null

systemctl restart \
  instana-demo-source.timer

ok "SOURCE timer" "ENABLED / ACTIVE"


# ============================================================
# CENTRAL
# ============================================================

validate_central

if (( FAILURES > 0 )); then

    echo
    echo "CENTRAL validation failed."
    echo "SOURCE job will not be forced."
    echo

else

    info "SOURCE publication" "FORCING ONE RUN"

    if systemctl start \
         instana-demo-source.service
    then
        ok "SOURCE forced run" "SUCCESS"
    else
        fail "SOURCE forced run" "FAILED"
    fi
fi


# ============================================================
# FINAL VALIDATION
# ============================================================

echo
echo "Final validation"

validate_runtime


echo
echo "========================================================"

if (( FAILURES == 0 )); then
    echo " BASTION SOURCE SETUP = COMPLETE"
else
    echo " BASTION SOURCE SETUP = FAILED"
fi

echo "========================================================"
echo
echo "Failures : ${FAILURES}"
echo "Warnings : ${WARNINGS}"
echo

exit "${FAILURES}"

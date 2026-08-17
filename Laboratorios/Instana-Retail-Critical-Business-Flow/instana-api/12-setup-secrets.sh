#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/opt/instana-demo"
SECRETS_DIR="${BASE_DIR}/secrets"

TOKEN_FILE="${SECRETS_DIR}/instana.token"
SYNTH_FILE="${SECRETS_DIR}/synthetic.env"

INSTANA_URL="${INSTANA_URL:-https://unit0-ibm.instana-0.ibmdte.local}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
RESET='\033[0m'

ok() {
    printf "${GREEN}[OK]   ${RESET} %-32s %s\n" "$1" "${2:-}"
}

fail() {
    printf "${RED}[FAIL] ${RESET} %-32s %s\n" "$1" "${2:-}"
}

warn() {
    printf "${YELLOW}[WARN] ${RESET} %-32s %s\n" "$1" "${2:-}"
}

mkdir -p "${SECRETS_DIR}"

chmod 700 "${SECRETS_DIR}"

umask 077


echo
echo "========================================================"
echo " INSTANA RETAIL LAB - CREDENTIAL SETUP"
echo "========================================================"
echo


# ============================================================
# INSTANA API TOKEN
# ============================================================

printf "${BOLD}Instana API${RESET}\n"


TOKEN_VALUE="${INSTANA_TOKEN:-}"

if [[ -z "${TOKEN_VALUE}" ]]; then

    IFS= read -rsp \
      "Instana API Token principal: " \
      TOKEN_VALUE

    echo
fi

TOKEN_VALUE="${TOKEN_VALUE//$'\r'/}"
TOKEN_VALUE="${TOKEN_VALUE//$'\n'/}"


if [[ -z "${TOKEN_VALUE}" ]]; then

    fail "Instana API Token" "EMPTY"
    exit 1
fi


TMP=$(mktemp)

HTTP=$(
  curl -skS \
    -o "${TMP}" \
    -w '%{http_code}' \
    -H "Authorization: apiToken ${TOKEN_VALUE}" \
    -H "Accept: application/json" \
    "${INSTANA_URL}/api/application-monitoring/catalog/metrics"
)

rm -f "${TMP}"


if [[ "${HTTP}" != "200" ]]; then

    fail "Instana API authentication" \
         "HTTP ${HTTP}"

    exit 1
fi


printf '%s\n' "${TOKEN_VALUE}" \
  > "${TOKEN_FILE}"

chmod 600 "${TOKEN_FILE}"

ok "Instana API authentication" "VALID"
ok "instana.token" "CREATED"


# ============================================================
# SYNTHETIC CREDENTIALS
# ============================================================

echo
printf "${BOLD}Synthetic PoP${RESET}\n"

echo
echo "Obtenga estos valores desde:"
echo "Synthetic Monitoring -> Locations -> Deploy a PoP -> Simple"
echo


IFS= read -rsp \
  "Synthetic downloadKey: " \
  SYNTH_DOWNLOAD_KEY
echo


IFS= read -rsp \
  "Synthetic controller.instanaKey: " \
  SYNTH_INSTANA_KEY
echo


IFS= read -rp \
  "Synthetic controller.instanaSyntheticEndpoint: " \
  SYNTH_ENDPOINT


IFS= read -rsp \
  "Synthetic redis.password: " \
  SYNTH_REDIS_PASSWORD
echo


SYNTH_DOWNLOAD_KEY="${SYNTH_DOWNLOAD_KEY//$'\r'/}"
SYNTH_INSTANA_KEY="${SYNTH_INSTANA_KEY//$'\r'/}"
SYNTH_ENDPOINT="${SYNTH_ENDPOINT//$'\r'/}"
SYNTH_REDIS_PASSWORD="${SYNTH_REDIS_PASSWORD//$'\r'/}"


if [[ -z "${SYNTH_DOWNLOAD_KEY}" \
   || -z "${SYNTH_INSTANA_KEY}" \
   || -z "${SYNTH_ENDPOINT}" \
   || -z "${SYNTH_REDIS_PASSWORD}" ]]; then

    fail "Synthetic credentials" \
         "INCOMPLETE"

    exit 1
fi


if [[ ! "${SYNTH_ENDPOINT}" =~ ^https:// ]]; then

    fail "Synthetic endpoint" \
         "HTTPS endpoint required"

    exit 1
fi


{
    printf 'SYNTHETIC_DOWNLOAD_KEY=%q\n' \
      "${SYNTH_DOWNLOAD_KEY}"

    printf 'SYNTHETIC_INSTANA_KEY=%q\n' \
      "${SYNTH_INSTANA_KEY}"

    printf 'SYNTHETIC_ENDPOINT=%q\n' \
      "${SYNTH_ENDPOINT}"

    printf 'SYNTHETIC_REDIS_PASSWORD=%q\n' \
      "${SYNTH_REDIS_PASSWORD}"

} > "${SYNTH_FILE}"


chmod 600 "${SYNTH_FILE}"


ok "Synthetic credentials" "STORED"
ok "synthetic.env" "CREATED"


# ============================================================
# PERMISSIONS
# ============================================================

echo
printf "${BOLD}Security${RESET}\n"


TOKEN_MODE=$(stat -c '%a' "${TOKEN_FILE}")
SYNTH_MODE=$(stat -c '%a' "${SYNTH_FILE}")
DIR_MODE=$(stat -c '%a' "${SECRETS_DIR}")


if [[ "${DIR_MODE}" == "700" ]]; then
    ok "secrets directory" "700"
else
    fail "secrets directory" "${DIR_MODE}"
    exit 1
fi


if [[ "${TOKEN_MODE}" == "600" ]]; then
    ok "instana.token" "600"
else
    fail "instana.token" "${TOKEN_MODE}"
    exit 1
fi


if [[ "${SYNTH_MODE}" == "600" ]]; then
    ok "synthetic.env" "600"
else
    fail "synthetic.env" "${SYNTH_MODE}"
    exit 1
fi


echo
echo "========================================================"
printf "${GREEN}${BOLD} CREDENTIAL SETUP = READY${RESET}\n"
echo "========================================================"
echo
echo "Secrets stored securely."
echo "No secret value was printed."
echo

#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/opt/instana-demo/instana-api"
STATE_DIR="${BASE_DIR}/state"

source "${BASE_DIR}/00-load-instana-env.sh"

mkdir -p "${STATE_DIR}"

WEBSITE_ID_FILE="${STATE_DIR}/website-id"

if [[ ! -s "${WEBSITE_ID_FILE}" ]]; then
  echo "[ERROR] No existe ${WEBSITE_ID_FILE}"
  echo "Ejecuta primero ./06-create-website.sh"
  exit 1
fi

WEBSITE_ID="$(tr -d '\r\n' < "${WEBSITE_ID_FILE}")"

UI_HOST="$(
  printf '%s' "${INSTANA_URL}" |
    sed -E 's#^https?://([^/:]+).*$#\1#'
)"

BASE_DOMAIN="${UI_HOST#*.}"

echo
echo "========================================================"
echo " INSTANA API | DESCUBRIMIENTO EUM"
echo "========================================================"
echo
printf " Instana UI     : %s\n" "${INSTANA_URL}"
printf " UI host        : %s\n" "${UI_HOST}"
printf " Base domain    : %s\n" "${BASE_DOMAIN}"
printf " Website ID     : %s\n" "${WEBSITE_ID}"
echo

candidates=(
  "https://eum.${BASE_DOMAIN}/eum/"
  "https://${BASE_DOMAIN}/eum/"
  "https://${UI_HOST}:446/eum/"
  "https://${UI_HOST}/eum/"
  "http://${UI_HOST}:86/eum/"
)

selected=""
tmp="$(mktemp)"
trap 'rm -f "${tmp}"' EXIT

echo "Probando endpoints EUM"
echo "--------------------------------------------------------"

for base in "${candidates[@]}"; do

  js_url="${base}eum.min.js"

  : > "${tmp}"

  code="$(
    curl -k -L -sS \
      --connect-timeout 4 \
      --max-time 10 \
      -o "${tmp}" \
      -w '%{http_code}' \
      "${js_url}" 2>/dev/null || true
  )"

  bytes="$(wc -c < "${tmp}" | tr -d ' ')"

  printf " %-55s HTTP=%-3s bytes=%s\n" \
    "${js_url}" \
    "${code:-000}" \
    "${bytes:-0}"

  if [[ "${code}" == "200" ]] && [[ "${bytes:-0}" -gt 1000 ]]; then
    selected="${base}"
    break
  fi
done

echo
echo "Resultado"
echo "--------------------------------------------------------"

if [[ -z "${selected}" ]]; then

  echo "[ERROR] No se encontró un endpoint EUM válido."
  echo
  echo "No se modificará NOVA todavía."
  echo
  echo "Candidatos evaluados:"
  printf ' - %s\n' "${candidates[@]}"

  exit 2
fi

REPORTING_URL="${selected}"
JS_AGENT_URL="${selected}eum.min.js"

#
# La REST API pública del Website no expone una segunda tracking key.
# Usamos el Website ID como monitoring-key candidato.
# Se validará posteriormente mediante beacons reales.
#
EUM_KEY="${WEBSITE_ID}"

cat > "${STATE_DIR}/eum.env" <<EOT
INSTANA_EUM_REPORTING_URL='${REPORTING_URL}'
INSTANA_EUM_JS_AGENT_URL='${JS_AGENT_URL}'
INSTANA_EUM_KEY='${EUM_KEY}'
INSTANA_EUM_WEBSITE_ID='${WEBSITE_ID}'
INSTANA_EUM_WEBSITE_NAME='RETAIL - NOVA Market'
EOT

cat > "${STATE_DIR}/eum.json" <<EOT
{
  "websiteId": "${WEBSITE_ID}",
  "websiteName": "RETAIL - NOVA Market",
  "reportingUrl": "${REPORTING_URL}",
  "jsAgentUrl": "${JS_AGENT_URL}",
  "monitoringKeyCandidate": "${EUM_KEY}"
}
EOT

echo "[OK] Endpoint EUM descubierto"
echo
printf " Reporting URL : %s\n" "${REPORTING_URL}"
printf " JS Agent URL  : %s\n" "${JS_AGENT_URL}"
printf " Website ID    : %s\n" "${WEBSITE_ID}"
printf " EUM Key       : %s\n" "${EUM_KEY}"

echo
echo "Validando JavaScript agent"
echo "--------------------------------------------------------"

curl -k -L -sS \
  --connect-timeout 5 \
  --max-time 15 \
  "${JS_AGENT_URL}" \
  -o "${STATE_DIR}/eum.min.js"

agent_size="$(wc -c < "${STATE_DIR}/eum.min.js" | tr -d ' ')"

if [[ "${agent_size}" -lt 1000 ]]; then
  echo "[ERROR] El agente descargado parece inválido."
  exit 3
fi

echo "[OK] eum.min.js accesible"
echo "     Tamaño: ${agent_size} bytes"

echo
echo "Estado persistido"
echo "--------------------------------------------------------"
echo " ${STATE_DIR}/eum.env"
echo " ${STATE_DIR}/eum.json"
echo " ${STATE_DIR}/eum.min.js"

echo
echo "--------------------------------------------------------"
echo " EUM ENDPOINT : READY"
echo "--------------------------------------------------------"

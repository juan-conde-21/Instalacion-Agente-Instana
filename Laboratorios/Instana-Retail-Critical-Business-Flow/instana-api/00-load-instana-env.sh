#!/usr/bin/env bash

#
# Configuración central de Instana API.
# Este archivo NO solicita credenciales interactivamente.
#

INSTANA_SECRET_FILE="/opt/instana-demo/secrets/instana-api.env"

if [[ ! -r "${INSTANA_SECRET_FILE}" ]]; then
  echo "[ERROR] No existe configuración persistente de Instana:"
  echo "        ${INSTANA_SECRET_FILE}"
  return 1 2>/dev/null || exit 1
fi

# shellcheck disable=SC1090
source "${INSTANA_SECRET_FILE}"

: "${INSTANA_URL:?INSTANA_URL no configurada}"
: "${INSTANA_TOKEN:?INSTANA_TOKEN no configurado}"

case "${INSTANA_TOKEN}" in
  TU_TOKEN_ACTUAL|CHANGE_ME|REPLACE_ME|"")
    echo "[ERROR] INSTANA_TOKEN contiene un placeholder."
    echo "        Configura una sola vez:"
    echo "        /opt/instana-demo/secrets/instana-api.env"
    return 1 2>/dev/null || exit 1
    ;;
esac

export INSTANA_URL
export INSTANA_TOKEN

#
# Normalización.
#
INSTANA_URL="${INSTANA_URL%/}"

echo
echo "Validando acceso a Instana..."

HTTP_CODE="$(
  curl -ksS \
    --connect-timeout 5 \
    --max-time 15 \
    -o /tmp/instana-api-validation.$$ \
    -w '%{http_code}' \
    -H "Authorization: apiToken ${INSTANA_TOKEN}" \
    "${INSTANA_URL}/api/website-monitoring/config" \
    2>/dev/null || true
)"

rm -f /tmp/instana-api-validation.$$

if [[ "${HTTP_CODE}" != "200" ]]; then
  echo "[ERROR] Instana API no accesible (HTTP ${HTTP_CODE:-000})"
  return 1 2>/dev/null || exit 1
fi

echo "Instana API: OK"
echo "URL: ${INSTANA_URL}"
echo "Token: cargado automáticamente (${#INSTANA_TOKEN} caracteres)"
echo

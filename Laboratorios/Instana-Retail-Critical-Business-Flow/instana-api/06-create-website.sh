#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/opt/instana-demo/instana-api"
STATE_DIR="${BASE_DIR}/state"

source "${BASE_DIR}/00-load-instana-env.sh"

mkdir -p "${STATE_DIR}"

WEBSITE_NAME="${WEBSITE_NAME:-RETAIL - NOVA Market}"

auth_header="Authorization: apiToken ${INSTANA_TOKEN}"

echo
echo "========================================================"
echo " INSTANA API | WEBSITE MONITORING"
echo "========================================================"
echo
printf " Website : %s\n" "${WEBSITE_NAME}"
echo

# --------------------------------------------------------
# Buscar Website existente
# --------------------------------------------------------

websites="$(
  curl -ksSf \
    -H "${auth_header}" \
    "${INSTANA_URL}/api/website-monitoring/config"
)"

website_id="$(
  jq -r \
    --arg name "${WEBSITE_NAME}" \
    '.[] | select(.name == $name) | .id' \
    <<<"${websites}" | head -1
)"

if [[ -n "${website_id}" ]]; then

  echo "[OK] Website ya existe"
  echo "     ID: ${website_id}"

else

  echo "[INFO] Creando Website..."

  encoded_name="$(
    jq -rn \
      --arg value "${WEBSITE_NAME}" \
      '$value | @uri'
  )"

  response="$(
    curl -ksSf \
      -X POST \
      -H "${auth_header}" \
      "${INSTANA_URL}/api/website-monitoring/config?name=${encoded_name}"
  )"

  website_id="$(jq -r '.id' <<<"${response}")"

  if [[ -z "${website_id}" || "${website_id}" == "null" ]]; then
    echo "[ERROR] Instana no devolvió websiteId"
    echo "${response}" | jq .
    exit 1
  fi

  echo "[OK] Website creado"
  echo "     ID: ${website_id}"
fi

# --------------------------------------------------------
# Obtener configuración efectiva
# --------------------------------------------------------

curl -ksSf \
  -H "${auth_header}" \
  "${INSTANA_URL}/api/website-monitoring/config/${website_id}" \
  > "${STATE_DIR}/website.json"

jq -r '.id' \
  "${STATE_DIR}/website.json" \
  > "${STATE_DIR}/website-id"

jq -r '.appName // empty' \
  "${STATE_DIR}/website.json" \
  > "${STATE_DIR}/website-app-name"

# --------------------------------------------------------
# Catálogo EUM de esta versión de Instana
# --------------------------------------------------------

curl -ksSf \
  -H "${auth_header}" \
  "${INSTANA_URL}/api/website-monitoring/catalog/metrics" \
  > "${STATE_DIR}/website-metrics.json"

curl -ksSf \
  -H "${auth_header}" \
  "${INSTANA_URL}/api/website-monitoring/catalog/tags" \
  > "${STATE_DIR}/website-tags.json"

echo
echo "Configuración devuelta por Instana"
echo "--------------------------------------------------------"
jq . "${STATE_DIR}/website.json"

echo
echo "Catálogo EUM"
echo "--------------------------------------------------------"
printf " Métricas : "
jq 'length' "${STATE_DIR}/website-metrics.json"

printf " Tags     : "
jq 'length' "${STATE_DIR}/website-tags.json"

echo
echo "--------------------------------------------------------"
echo " WEBSITE MONITORING : CONFIGURADO"
echo "--------------------------------------------------------"

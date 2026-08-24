#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(
  cd "$(dirname "${BASH_SOURCE[0]}")"   && pwd
)"

BASE_DIR="${SCRIPT_DIR}"
API_DIR="${SCRIPT_DIR}"
STATE_DIR="${BASE_DIR}/state"
OUT_DIR="${STATE_DIR}/dependencies"

source "${BASE_DIR}/00-load-instana-env.sh"

mkdir -p "${OUT_DIR}"

AUTH="Authorization: apiToken ${INSTANA_TOKEN}"

source "${SCRIPT_DIR}/00-load-runtime-ids.sh"

APPLICATION_ID="${APP_ID}"

TO_MS="$(( $(date +%s) * 1000 ))"
WINDOW_MS=3600000

INBOUND_FILE="${OUT_DIR}/topology-inbound.json"
ALL_FILE="${OUT_DIR}/topology-all.json"

echo
echo "========================================================"
echo " INSTANA | SERVICE DEPENDENCY TOPOLOGY"
echo "========================================================"
echo
echo " Application : RETAIL - Critical Promotions Flow"
echo " Retail      : ${RETAIL_ID}"
echo " Central     : ${CENTRAL_ID}"
echo


query_topology() {

  local scope="$1"
  local file="$2"

  echo "Consultando scope ${scope}..."

  HTTP_CODE="$(
    curl -ksS \
      -o "${file}" \
      -w '%{http_code}' \
      -H "${AUTH}" \
      -H "Accept: application/json" \
      "${INSTANA_URL}/api/application-monitoring/topology/services?to=${TO_MS}&windowSize=${WINDOW_MS}&applicationId=${APPLICATION_ID}&applicationBoundaryScope=${scope}" \
      || true
  )"

  if [[ "${HTTP_CODE}" != "200" ]]; then

    echo "[ERROR] Topology API HTTP ${HTTP_CODE}"

    if [[ -s "${file}" ]]; then
      jq . "${file}" 2>/dev/null || cat "${file}"
    fi

    return 1
  fi

  echo "[OK] Topology ${scope} HTTP 200"
}


query_topology \
  "INBOUND" \
  "${INBOUND_FILE}"

query_topology \
  "ALL" \
  "${ALL_FILE}"


echo
echo "========================================================"
echo " TOPOLOGY INBOUND"
echo "========================================================"

echo
echo "Estructura"
echo "--------------------------------------------------------"

jq '{
  keys: keys,
  serviceCount: ((.services // []) | length),
  connectionCount: ((.connections // []) | length)
}' "${INBOUND_FILE}"


echo
echo "Servicios"
echo "--------------------------------------------------------"

jq '
  (.services // [])
  | map({
      id: .id,
      label: (.label // .name // .serviceName),
      types: .types
    })
' "${INBOUND_FILE}"


echo
echo "Connections RAW"
echo "--------------------------------------------------------"

jq '
  (.connections // [])
' "${INBOUND_FILE}"


echo
echo "Estructura de connections"
echo "--------------------------------------------------------"

jq '
  (.connections // [])
  | map(keys)
  | unique
' "${INBOUND_FILE}"


echo
echo "========================================================"
echo " VALIDACIÓN RETAIL -> CENTRAL"
echo "========================================================"


#
# No asumimos todavía los nombres de los campos.
# Buscamos una conexión que contenga ambos IDs.
#
MATCHES="$(
  jq \
    --arg retail "${RETAIL_ID}" \
    --arg central "${CENTRAL_ID}" '
      [
        (.connections // [])[]
        | select(
            (
              tostring
              | contains($retail)
            )
            and
            (
              tostring
              | contains($central)
            )
          )
      ]
    ' "${INBOUND_FILE}"
)"


MATCH_COUNT="$(
  jq 'length' <<< "${MATCHES}"
)"


if [[ "${MATCH_COUNT}" -gt 0 ]]; then

  echo
  echo "[OK] Instana registra una conexión"
  echo "     entre retail-app y central-service."
  echo

  jq . <<< "${MATCHES}"

else

  echo
  echo "[INFO] No encontré ambos IDs juntos"
  echo "       en topology scope INBOUND."
  echo
  echo "Revisando scope ALL..."


  MATCHES_ALL="$(
    jq \
      --arg retail "${RETAIL_ID}" \
      --arg central "${CENTRAL_ID}" '
        [
          (.connections // [])[]
          | select(
              (
                tostring
                | contains($retail)
              )
              and
              (
                tostring
                | contains($central)
              )
            )
        ]
      ' "${ALL_FILE}"
  )"


  MATCH_COUNT_ALL="$(
    jq 'length' <<< "${MATCHES_ALL}"
  )"


  if [[ "${MATCH_COUNT_ALL}" -gt 0 ]]; then

    echo
    echo "[OK] Conexión encontrada con scope ALL."
    echo

    jq . <<< "${MATCHES_ALL}"

  else

    echo
    echo "[WARN] La topología contiene los servicios,"
    echo "       pero no encontré todavía la arista"
    echo "       retail-app -> central-service."
    echo
    echo "Será necesario revisar una trace real."

  fi

fi


echo
echo "========================================================"
echo " RESUMEN"
echo "========================================================"

printf " INBOUND services    : "
jq -r '(.services // []) | length' "${INBOUND_FILE}"

printf " INBOUND connections : "
jq -r '(.connections // []) | length' "${INBOUND_FILE}"

printf " ALL services        : "
jq -r '(.services // []) | length' "${ALL_FILE}"

printf " ALL connections     : "
jq -r '(.connections // []) | length' "${ALL_FILE}"

echo
echo "Archivos:"
echo " ${INBOUND_FILE}"
echo " ${ALL_FILE}"

echo
echo "--------------------------------------------------------"
echo " SERVICE TOPOLOGY : COMPLETE"
echo "--------------------------------------------------------"

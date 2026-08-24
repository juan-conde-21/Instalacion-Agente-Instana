#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/opt/instana-demo/instana-api"
STATE_DIR="${BASE_DIR}/state"
OUT_DIR="${STATE_DIR}/eum-validation"

source "${BASE_DIR}/00-load-instana-env.sh"

mkdir -p "${OUT_DIR}"

WEBSITE_JSON="${STATE_DIR}/website.json"
WEBSITE_ID_FILE="${STATE_DIR}/website-id"

if [[ ! -s "${WEBSITE_JSON}" ]]; then
  echo "[ERROR] Falta ${WEBSITE_JSON}"
  exit 1
fi

if [[ ! -s "${WEBSITE_ID_FILE}" ]]; then
  echo "[ERROR] Falta ${WEBSITE_ID_FILE}"
  exit 1
fi

WEBSITE_NAME="$(
  jq -r '.name' "${WEBSITE_JSON}"
)"

WEBSITE_ID="$(
  tr -d '\r\n' < "${WEBSITE_ID_FILE}"
)"

AUTH="Authorization: apiToken ${INSTANA_TOKEN}"

#
# Última hora.
#
TO_MS="$(( $(date +%s) * 1000 ))"
WINDOW_MS=3600000

echo
echo "========================================================"
echo " INSTANA API | VALIDACIÓN WEBSITE EUM"
echo "========================================================"
echo
printf " Website       : %s\n" "${WEBSITE_NAME}"
printf " Website ID    : %s\n" "${WEBSITE_ID}"
printf " Ventana       : últimos 60 minutos\n"
echo

types=(
  PAGELOAD
  PAGE_CHANGE
  HTTPREQUEST
  CUSTOM
  ERROR
)

total_all=0

for type in "${types[@]}"; do

  echo "--------------------------------------------------------"
  printf " Beacon type : %s\n" "${type}"
  echo "--------------------------------------------------------"

  payload="$(
    jq -n \
      --arg type "${type}" \
      --arg website "${WEBSITE_NAME}" \
      --argjson to "${TO_MS}" \
      --argjson window "${WINDOW_MS}" \
      '{
        type: $type,
        timeFrame: {
          to: $to,
          windowSize: $window
        },
        tagFilters: [
          {
            name: "beacon.website.name",
            operator: "EQUALS",
            value: $website
          }
        ]
      }'
  )"

  outfile="${OUT_DIR}/${type}.json"
  errfile="${OUT_DIR}/${type}.error"

  http_code="$(
    curl -ksS \
      -o "${outfile}" \
      -w '%{http_code}' \
      -X POST \
      -H "${AUTH}" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      --data "${payload}" \
      "${INSTANA_URL}/api/website-monitoring/analyze/beacons" \
      2>"${errfile}" || true
  )"

  if [[ "${http_code}" != "200" ]]; then

    echo "[ERROR] API HTTP ${http_code}"

    if [[ -s "${outfile}" ]]; then
      cat "${outfile}"
      echo
    fi

    if [[ -s "${errfile}" ]]; then
      cat "${errfile}"
      echo
    fi

    continue
  fi

  count="$(
    jq '
      if (.totalHits != null)
      then .totalHits
      else (.items // [] | length)
      end
    ' "${outfile}"
  )"

  printf " Beacons       : %s\n" "${count}"

  total_all="$(( total_all + count ))"

  if [[ "${count}" -eq 0 ]]; then

    echo "[INFO] Sin datos para ${type}"
    echo
    continue

  fi

  echo
  echo "Website IDs observados"
  echo "........................"

  jq -r '
    [
      .items[]?
      | .beacon.websiteId
      | select(. != null)
    ]
    | unique[]
  ' "${outfile}" || true

  echo
  echo "Campos presentes en estos beacons"
  echo ".................................."

  jq -r '
    [
      .items[]?
      | .beacon
      | keys[]
    ]
    | unique
    | join(", ")
  ' "${outfile}" || true

  echo
  echo "Muestra de beacons"
  echo ".................."

  jq '
    .items[:5]
    | map(
        .beacon
        | {
            type,
            timestamp,
            websiteId,
            websiteLabel,
            page: .page,
            userId,
            userName,
            locationUrl,
            method: .httpCallMethod,
            path: .httpCallPath,
            httpStatus: .httpCallStatus,
            customEventName,
            duration,
            backendTraceId
          }
      )
  ' "${outfile}"

  echo

done


echo "========================================================"
echo " RESUMEN EUM"
echo "========================================================"
echo
printf " Website       : %s\n" "${WEBSITE_NAME}"
printf " Website ID    : %s\n" "${WEBSITE_ID}"
printf " Total beacons : %s\n" "${total_all}"
echo

if [[ "${total_all}" -gt 0 ]]; then

  echo "[OK] Instana está recibiendo Website Monitoring data."
  echo

  observed_ids="$(
    jq -r '
      .items[]?
      | .beacon.websiteId
      | select(. != null)
    ' "${OUT_DIR}"/*.json 2>/dev/null |
      sort -u
  )"

  if grep -qx "${WEBSITE_ID}" <<<"${observed_ids}"; then

    echo "[OK] Website ID observado en los beacons:"
    echo "     ${WEBSITE_ID}"
    echo
    echo "[OK] La configuración EUM está asociando tráfico"
    echo "     con RETAIL - NOVA Market."

  else

    echo "[WARN] Existen beacons, pero no aparece el Website ID esperado."
    echo
    echo "IDs encontrados:"
    printf '%s\n' "${observed_ids}"

  fi

else

  echo "[WARN] No se encontraron beacons del Website."
  echo
  echo "Esto todavía NO demuestra un problema del backend."
  echo "Debemos validar desde el navegador:"
  echo
  echo "  1. resolución DNS de instana-0.ibmdte.local"
  echo "  2. descarga de /eum/eum.min.js"
  echo "  3. requests hacia /eum/"
  echo "  4. monitoring key aceptada"
fi

echo
echo "Resultados raw:"
echo " ${OUT_DIR}"
echo
echo "--------------------------------------------------------"
echo " EUM VALIDATION : COMPLETE"
echo "--------------------------------------------------------"

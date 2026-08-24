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
APPLICATION_LABEL="RETAIL - Critical Promotions Flow"

TO_MS="$(( $(date +%s) * 1000 ))"
WINDOW_MS=3600000

APPS_FILE="${OUT_DIR}/applications.json"
SERVICES_FILE="${OUT_DIR}/services.json"
TRACE_FILE="${OUT_DIR}/trace-services.json"
REQUEST_FILE="${OUT_DIR}/trace-services-request.json"

echo
echo "========================================================"
echo " INSTANA | DEPENDENCIES PREFLIGHT"
echo "========================================================"
echo
echo " Application : ${APPLICATION_LABEL}"
echo " ID          : ${APPLICATION_ID}"
echo


# --------------------------------------------------------
# 1. Obtener Application desde listado
# --------------------------------------------------------

echo "1. Application Perspective"
echo "--------------------------------------------------------"

curl -ksSf \
  -H "${AUTH}" \
  -H "Accept: application/json" \
  "${INSTANA_URL}/api/application-monitoring/applications?to=${TO_MS}&windowSize=${WINDOW_MS}" \
  > "${APPS_FILE}"

jq \
  --arg appId "${APPLICATION_ID}" '
    .items[]
    | select(.id == $appId)
    | {
        id: .id,
        label: .label,
        boundaryScope: .boundaryScope,
        entityType: .entityType
      }
  ' "${APPS_FILE}"


# --------------------------------------------------------
# 2. Servicios de la Application
# --------------------------------------------------------

echo
echo "2. Servicios de la Application"
echo "--------------------------------------------------------"

curl -ksSf \
  -H "${AUTH}" \
  -H "Accept: application/json" \
  "${INSTANA_URL}/api/application-monitoring/applications;id=${APPLICATION_ID}/services?to=${TO_MS}&windowSize=${WINDOW_MS}" \
  > "${SERVICES_FILE}"

jq '
  if type == "object" and .items then
    {
      totalHits:
        (.totalHits // (.items | length)),

      services:
        [
          .items[]
          | {
              id: .id,
              label: (.label // .name),
              entityType: .entityType,
              types: .types
            }
        ]
    }

  elif type == "array" then
    {
      totalHits: length,

      services:
        [
          .[]
          | {
              id: .id,
              label: (.label // .name),
              entityType: .entityType,
              types: .types
            }
        ]
    }

  else
    .
  end
' "${SERVICES_FILE}"


# --------------------------------------------------------
# 3. Servicios con trace data real
# --------------------------------------------------------

echo
echo "3. Call Analytics - última hora"
echo "--------------------------------------------------------"

jq -n \
  --arg appId "${APPLICATION_ID}" \
  --argjson to "${TO_MS}" \
  --argjson window "${WINDOW_MS}" '
{
  timeFrame: {
    to: $to,
    windowSize: $window
  },

  tagFilterExpression: {
    type: "TAG_FILTER",
    name: "application.name",
    operator: "EQUALS",
    entity: "DESTINATION",
    value: $appId
  },

  metrics: [
    {
      metric: "calls",
      aggregation: "SUM"
    },
    {
      metric: "errors",
      aggregation: "MEAN"
    },
    {
      metric: "latency",
      aggregation: "MEAN"
    }
  ],

  group: {
    groupbyTag: "service.name",
    groupbyTagEntity: "DESTINATION"
  }
}
' > "${REQUEST_FILE}"


HTTP_CODE="$(
  curl -ksS \
    -o "${TRACE_FILE}" \
    -w '%{http_code}' \
    -X POST \
    -H "${AUTH}" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    --data @"${REQUEST_FILE}" \
    "${INSTANA_URL}/api/application-monitoring/analyze/call-groups" \
    || true
)"


if [[ "${HTTP_CODE}" == "200" ]]; then

  echo "[OK] Call Analytics HTTP 200"
  echo

  jq . "${TRACE_FILE}"

else

  echo "[WARN] Call Analytics HTTP ${HTTP_CODE}"
  cat "${TRACE_FILE}"

fi


# --------------------------------------------------------
# 4. Buscar RETAIL / CENTRAL
# --------------------------------------------------------

echo
echo "4. Hallazgos RETAIL / CENTRAL"
echo "--------------------------------------------------------"

jq '
  [
    ..
    | objects

    | select(
        (
          (
            .label? //
            .name? //
            .group? //
            ""
          )
          | tostring
          | test("retail|central"; "i")
        )
      )
  ]
' "${SERVICES_FILE}"


echo
echo "--------------------------------------------------------"
echo " DEPENDENCIES PREFLIGHT : COMPLETE"
echo "--------------------------------------------------------"

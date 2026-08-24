#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/opt/instana-demo/instana-api"
STATE_DIR="${BASE_DIR}/state"
OUT_DIR="${STATE_DIR}/website-alerts"

source "${BASE_DIR}/00-load-instana-env.sh"

mkdir -p "${OUT_DIR}"

WEBSITE_ID="$(
  tr -d '\r\n' < "${STATE_DIR}/website-id"
)"

WEBSITE_NAME="$(
  jq -r '.name' "${STATE_DIR}/website.json"
)"

AUTH="Authorization: apiToken ${INSTANA_TOKEN}"

METRICS="${OUT_DIR}/metrics.json"
TAGS="${OUT_DIR}/tags.json"
CUSTOM="${OUT_DIR}/custom-beacons.json"

echo
echo "========================================================"
echo " INSTANA API | CUSTOM EVENT ALERT DISCOVERY"
echo "========================================================"
echo
printf " Website : %s\n" "${WEBSITE_NAME}"
echo

# --------------------------------------------------------
# Refrescar catálogo real
# --------------------------------------------------------

curl -ksSf \
  -H "${AUTH}" \
  "${INSTANA_URL}/api/website-monitoring/catalog/metrics" \
  > "${METRICS}"

curl -ksSf \
  -H "${AUTH}" \
  "${INSTANA_URL}/api/website-monitoring/catalog/tags" \
  > "${TAGS}"


echo "========================================================"
echo " MÉTRICAS PARA BEACONS CUSTOM"
echo "========================================================"
echo

jq '
[
  ..
  | objects
  | select(
      (
        .beaconTypes? //
        []
      )
      | index("custom")
    )
  | {
      metricId: .metricId,
      label: .label,
      description: .description,
      aggregations: .aggregations,
      beaconTypes: .beaconTypes
    }
]
| unique_by(.metricId)
' "${METRICS}"


echo
echo "========================================================"
echo " TAGS CUSTOM EVENT"
echo "========================================================"
echo

jq '
[
  ..
  | objects
  | select(
      (.name? // "")
      | test("customEvent"; "i")
    )
  | {
      name: .name,
      label: .label
    }
]
| unique_by(.name)
' "${TAGS}"


# --------------------------------------------------------
# Recuperar CUSTOM beacons reales de NOVA
# --------------------------------------------------------

TO_MS="$(( $(date +%s) * 1000 ))"
WINDOW_MS=3600000

jq -n \
  --arg website "${WEBSITE_NAME}" \
  --argjson to "${TO_MS}" \
  --argjson window "${WINDOW_MS}" '
{
  type: "CUSTOM",

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
}
' > "${OUT_DIR}/custom-beacons-request.json"


curl -ksSf \
  -X POST \
  -H "${AUTH}" \
  -H "Content-Type: application/json" \
  --data @"${OUT_DIR}/custom-beacons-request.json" \
  "${INSTANA_URL}/api/website-monitoring/analyze/beacons" \
  > "${CUSTOM}"


echo
echo "========================================================"
echo " CUSTOM EVENTS OBSERVADOS"
echo "========================================================"
echo

jq '
[
  .items[]?.beacon.customEventName
  | select(
      . != null
      and
      . != ""
    )
]
| group_by(.)
| map({
    event: .[0],
    occurrences: length
  })
| sort_by(.occurrences)
| reverse
' "${CUSTOM}"


echo
echo "========================================================"
echo " CHECKOUT FAILED"
echo "========================================================"
echo

jq '
[
  .items[]?.beacon
  | select(
      .customEventName ==
      "NOVA Checkout Failed"
    )
  | {
      timestamp,
      page,
      userId,
      userName,
      event: .customEventName,
      duration,
      meta
    }
]
| sort_by(.timestamp)
| reverse
| .[:20]
' "${CUSTOM}"


echo
echo "--------------------------------------------------------"
echo " CUSTOM EVENT DISCOVERY : READY"
echo "--------------------------------------------------------"

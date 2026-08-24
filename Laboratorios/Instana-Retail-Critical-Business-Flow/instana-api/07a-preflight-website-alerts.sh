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

echo
echo "========================================================"
echo " INSTANA API | WEBSITE ALERTS PREFLIGHT"
echo "========================================================"
echo
printf " Website       : %s\n" "${WEBSITE_NAME}"
printf " Website ID    : %s\n" "${WEBSITE_ID}"
echo


# --------------------------------------------------------
# Website Smart Alerts existentes
# --------------------------------------------------------

echo "Consultando Website Smart Alerts..."
echo

curl -ksSf \
  -H "${AUTH}" \
  -H "Accept: application/json" \
  "${INSTANA_URL}/api/events/settings/website-alert-configs" \
  > "${OUT_DIR}/website-alert-configs.json"

echo "[OK] Configuraciones obtenidas"


# --------------------------------------------------------
# Alert Channels
# --------------------------------------------------------

echo "Consultando Alert Channels..."

curl -ksSf \
  -H "${AUTH}" \
  -H "Accept: application/json" \
  "${INSTANA_URL}/api/events/settings/alertingChannels" \
  > "${OUT_DIR}/alerting-channels.json"

echo "[OK] Canales obtenidos"


# --------------------------------------------------------
# Catálogo Website actualizado
# --------------------------------------------------------

echo "Actualizando catálogo Website..."

curl -ksSf \
  -H "${AUTH}" \
  -H "Accept: application/json" \
  "${INSTANA_URL}/api/website-monitoring/catalog/metrics" \
  > "${OUT_DIR}/metrics.json"

curl -ksSf \
  -H "${AUTH}" \
  -H "Accept: application/json" \
  "${INSTANA_URL}/api/website-monitoring/catalog/tags" \
  > "${OUT_DIR}/tags.json"

echo "[OK] Catálogo actualizado"


echo
echo "========================================================"
echo " ALERTAS ACTUALES PARA NOVA"
echo "========================================================"
echo

jq \
  --arg wid "${WEBSITE_ID}" '
    (
      if type == "array"
      then .
      else (.items // .configs // [])
      end
    )
    | map(
        select(
          (.websiteId // .website_id // "") == $wid
        )
      )
    | map({
        id,
        name,
        enabled,
        websiteId,
        severity,
        triggering,
        rule,
        rules,
        timeThreshold
      })
' "${OUT_DIR}/website-alert-configs.json"


echo
echo "========================================================"
echo " ALERT CHANNELS DISPONIBLES"
echo "========================================================"
echo

jq '
  (
    if type == "array"
    then .
    else (.items // .channels // [])
    end
  )
  | map({
      id,
      name,
      kind,
      type
    })
' "${OUT_DIR}/alerting-channels.json"


echo
echo "========================================================"
echo " MÉTRICAS CANDIDATAS"
echo "========================================================"
echo

jq -r '
  ..
  | objects
  | select(
      (
        (.metricId? // "") +
        " " +
        (.metric? // "") +
        " " +
        (.label? // "") +
        " " +
        (.description? // "")
      )
      | test(
          "http|status|custom|event";
          "i"
        )
    )
  | {
      metricId: .metricId,
      metric: .metric,
      label: .label,
      description: .description,
      aggregations: .aggregations,
      beaconTypes: .beaconTypes
    }
' "${OUT_DIR}/metrics.json"


echo
echo "========================================================"
echo " TAGS CANDIDATOS"
echo "========================================================"
echo

jq -r '
  ..
  | objects
  | select(
      (
        (.name? // "") +
        " " +
        (.label? // "")
      )
      | test(
          "custom|event|http|status|page|user|meta";
          "i"
        )
    )
  | {
      name: .name,
      label: .label
    }
' "${OUT_DIR}/tags.json"


echo
echo "Estado persistido"
echo "--------------------------------------------------------"
echo " ${OUT_DIR}/website-alert-configs.json"
echo " ${OUT_DIR}/alerting-channels.json"
echo " ${OUT_DIR}/metrics.json"
echo " ${OUT_DIR}/tags.json"

echo
echo "--------------------------------------------------------"
echo " WEBSITE ALERT PREFLIGHT : READY"
echo "--------------------------------------------------------"

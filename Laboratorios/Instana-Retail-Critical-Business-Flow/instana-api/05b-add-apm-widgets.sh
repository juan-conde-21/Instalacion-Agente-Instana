#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/opt/instana-demo/instana-api"
STATE_DIR="${BASE_DIR}/state"
CONFIG_DIR="${BASE_DIR}/config"

DASHBOARD_TITLE="RETAIL - Critical Business Flow"
APP_NAME="RETAIL - Critical Promotions Flow"

: "${INSTANA_URL:?Debe cargar 00-load-instana-env.sh}"
: "${INSTANA_TOKEN:?Debe cargar 00-load-instana-env.sh}"

mkdir -p "${STATE_DIR}" "${CONFIG_DIR}"

DASHBOARD_ID=$(cat "${STATE_DIR}/dashboard-id")
TECH_SLO_ID=$(cat "${STATE_DIR}/slo-technical-id")
BUS_SLO_ID=$(cat "${STATE_DIR}/slo-business-id")

TECH_WIDGET_ID=$(cat "${STATE_DIR}/widget-slo-technical-indicator-id")
BUS_WIDGET_ID=$(cat "${STATE_DIR}/widget-slo-indicator-id")
BUDGET_WIDGET_ID=$(cat "${STATE_DIR}/widget-slo-error-budget-id")


echo
echo "=============================================="
echo " RETAIL DASHBOARD - ADD APM"
echo "=============================================="


# ============================================================
# 1 - GET CURRENT DASHBOARD
# ============================================================

echo
echo "=== [1/6] Leyendo dashboard actual ==="

HTTP_CODE=$(curl -skS \
  -o "${CONFIG_DIR}/dashboard-before-apm.json" \
  -w '%{http_code}' \
  -H "Authorization: apiToken ${INSTANA_TOKEN}" \
  -H "Accept: application/json" \
  "${INSTANA_URL}/api/custom-dashboard/${DASHBOARD_ID}")

echo "HTTP=${HTTP_CODE}"

[[ "${HTTP_CODE}" == "200" ]] || {
    cat "${CONFIG_DIR}/dashboard-before-apm.json"
    exit 1
}


# ============================================================
# 2 - DISCOVER CALLS WIDGET
# ============================================================

echo
echo "=== [2/6] Leyendo schema APM descubierto ==="

CALLS_WIDGET=$(
  jq -c '
    .widgets[] |
    select(
      .title == "RETAIL - APM Calls - DISCOVERY"
      or (
        .type == "chart"
        and .config.y1.metrics[0].metric == "calls"
      )
    )
  ' "${CONFIG_DIR}/dashboard-before-apm.json" |
  head -1
)

[[ -n "${CALLS_WIDGET}" ]] || {
    echo "ERROR: no encuentro el widget APM Calls de descubrimiento."
    exit 1
}

CALLS_WIDGET_ID=$(jq -r '.id' <<<"${CALLS_WIDGET}")

echo "${CALLS_WIDGET_ID}" \
  > "${STATE_DIR}/widget-apm-calls-id"

echo "Calls widget:"
echo "  ${CALLS_WIDGET_ID}"


# ============================================================
# 3 - IDS ERRORS / LATENCY
# ============================================================

echo
echo "=== [3/6] Preparando IDs APM ==="

ensure_id() {
    local file="$1"

    if [[ ! -s "${file}" ]]; then
        tr -d '-' < /proc/sys/kernel/random/uuid \
          | cut -c1-16 > "${file}"
    fi
}

ensure_id "${STATE_DIR}/widget-apm-errors-id"
ensure_id "${STATE_DIR}/widget-apm-latency-id"

ERRORS_WIDGET_ID=$(cat "${STATE_DIR}/widget-apm-errors-id")
LATENCY_WIDGET_ID=$(cat "${STATE_DIR}/widget-apm-latency-id")

echo "Calls:"
echo "  ${CALLS_WIDGET_ID}"

echo "Errors:"
echo "  ${ERRORS_WIDGET_ID}"

echo "Latency:"
echo "  ${LATENCY_WIDGET_ID}"


# ============================================================
# 4 - BUILD SIX-WIDGET DASHBOARD
# ============================================================

echo
echo "=== [4/6] Construyendo dashboard declarativo ==="

ACCESS_RULES=$(
  jq -c '.accessRules' \
    "${CONFIG_DIR}/dashboard-before-apm.json"
)

CALLS_CONFIG=$(jq -c '.config' <<<"${CALLS_WIDGET}")


jq -n \
  --arg dashboard_id "${DASHBOARD_ID}" \
  --arg title "${DASHBOARD_TITLE}" \
  --arg tech_slo "${TECH_SLO_ID}" \
  --arg bus_slo "${BUS_SLO_ID}" \
  --arg tech_widget "${TECH_WIDGET_ID}" \
  --arg bus_widget "${BUS_WIDGET_ID}" \
  --arg budget_widget "${BUDGET_WIDGET_ID}" \
  --arg calls_widget "${CALLS_WIDGET_ID}" \
  --arg errors_widget "${ERRORS_WIDGET_ID}" \
  --arg latency_widget "${LATENCY_WIDGET_ID}" \
  --arg app_name "${APP_NAME}" \
  --argjson access_rules "${ACCESS_RULES}" \
  --argjson calls_config "${CALLS_CONFIG}" \
'
{
  id: $dashboard_id,
  title: $title,

  accessRules: $access_rules,

  widgets: [

    {
      width: 1,
      height: 1,
      x: 0,
      y: 0,

      id: $tech_widget,

      title: "RETAIL - Technical Availability - Indicator",

      type: "slo2",

      config: {
        sloId: $tech_slo,
        entityType: "synthetic",
        chartType: "INDICATOR"
      }
    },

    {
      width: 1,
      height: 1,
      x: 1,
      y: 0,

      id: $bus_widget,

      title: "RETAIL - Business Availability - Indicator",

      type: "slo2",

      config: {
        sloId: $bus_slo,
        entityType: "synthetic",
        chartType: "INDICATOR"
      }
    },

    {
      width: 1,
      height: 1,
      x: 0,
      y: 1,

      id: $budget_widget,

      title: "RETAIL - Business Availability - Error Budget",

      type: "slo2",

      config: {
        sloId: $bus_slo,
        entityType: "synthetic",
        chartType: "ERROR_BUDGET"
      }
    },

    {
      width: 1,
      height: 1,
      x: 0,
      y: 2,

      id: $calls_widget,

      title: "RETAIL - APM Calls",

      type: "chart",

      config:
        (
          $calls_config
          |
          .y1.metrics[0].metric = "calls"
          |
          .y1.metrics[0].aggregation = "SUM"
          |
          .y1.metrics[0].metricLabel = "Calls"
          |
          .y1.metrics[0].tagFilterExpression.value = $app_name
        )
    },

    {
      width: 1,
      height: 1,
      x: 1,
      y: 2,

      id: $errors_widget,

      title: "RETAIL - APM Error Rate",

      type: "chart",

      config:
        (
          $calls_config
          |
          .y1.formatter = "percentage.detailed"
          |
          .y1.metrics[0].metric = "errors"
          |
          .y1.metrics[0].aggregation = "MEAN"
          |
          .y1.metrics[0].metricLabel = "Erroneous calls (rate)"
          |
          .y1.metrics[0].tagFilterExpression.value = $app_name
        )
    },

    {
      width: 1,
      height: 1,
      x: 0,
      y: 3,

      id: $latency_widget,

      title: "RETAIL - APM Latency (ms)",

      type: "chart",

      config:
        (
          $calls_config
          |
          .y1.formatter = "latency.detailed"
          |
          .y1.metrics[0].metric = "latency"
          |
          .y1.metrics[0].aggregation = "MEAN"
          |
          .y1.metrics[0].metricLabel = "Latency"
          |
          .y1.metrics[0].tagFilterExpression.value = $app_name
        )
    }

  ]
}
' > "${CONFIG_DIR}/dashboard-six-widgets.json"


jq . "${CONFIG_DIR}/dashboard-six-widgets.json" >/dev/null

echo "JSON=OK"
echo "Widgets declarados: $(jq '.widgets | length' "${CONFIG_DIR}/dashboard-six-widgets.json")"


# ============================================================
# 5 - PUT
# ============================================================

echo
echo "=== [5/6] Actualizando Instana ==="

HTTP_CODE=$(curl -skS \
  -o "${CONFIG_DIR}/dashboard-apm-put-response.json" \
  -w '%{http_code}' \
  -X PUT \
  -H "Authorization: apiToken ${INSTANA_TOKEN}" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  --data @"${CONFIG_DIR}/dashboard-six-widgets.json" \
  "${INSTANA_URL}/api/custom-dashboard/${DASHBOARD_ID}")

echo "HTTP=${HTTP_CODE}"

if [[ ! "${HTTP_CODE}" =~ ^2 ]]; then
    cat "${CONFIG_DIR}/dashboard-apm-put-response.json"
    exit 1
fi


# ============================================================
# 6 - READ-BACK / VALIDATION
# ============================================================

echo
echo "=== [6/6] Validando read-back ==="

HTTP_CODE=$(curl -skS \
  -o "${CONFIG_DIR}/dashboard-six-widgets-current.json" \
  -w '%{http_code}' \
  -H "Authorization: apiToken ${INSTANA_TOKEN}" \
  -H "Accept: application/json" \
  "${INSTANA_URL}/api/custom-dashboard/${DASHBOARD_ID}")

echo "HTTP=${HTTP_CODE}"

[[ "${HTTP_CODE}" == "200" ]] || exit 1


jq '
{
  id,
  title,
  writable,

  widgetCount: (.widgets | length),

  widgets: [
    .widgets[] |
    {
      id,
      title,
      type,
      metric: (.config.y1.metrics[0].metric // null),
      aggregation: (.config.y1.metrics[0].aggregation // null),
      sloId: (.config.sloId // null),
      chartType: (.config.chartType // null)
    }
  ]
}
' "${CONFIG_DIR}/dashboard-six-widgets-current.json"


echo
echo "Validación funcional..."


jq -e \
  --arg tech_slo "${TECH_SLO_ID}" \
  --arg bus_slo "${BUS_SLO_ID}" \
'
(.widgets | length) == 6

and

any(
  .widgets[];
  .type == "slo2"
  and .config.sloId == $tech_slo
  and .config.chartType == "INDICATOR"
)

and

any(
  .widgets[];
  .type == "slo2"
  and .config.sloId == $bus_slo
  and .config.chartType == "INDICATOR"
)

and

any(
  .widgets[];
  .type == "slo2"
  and .config.sloId == $bus_slo
  and .config.chartType == "ERROR_BUDGET"
)

and

any(
  .widgets[];
  .type == "chart"
  and .config.y1.metrics[0].metric == "calls"
  and .config.y1.metrics[0].aggregation == "SUM"
)

and

any(
  .widgets[];
  .type == "chart"
  and .config.y1.metrics[0].metric == "errors"
  and .config.y1.metrics[0].aggregation == "MEAN"
)

and

any(
  .widgets[];
  .type == "chart"
  and .config.y1.metrics[0].metric == "latency"
  and .config.y1.metrics[0].aggregation == "MEAN"
)
' "${CONFIG_DIR}/dashboard-six-widgets-current.json" >/dev/null


echo
echo "=============================================="
echo " DASHBOARD 6 WIDGETS = PASS"
echo "=============================================="
echo
echo "SLO:"
echo "  Technical Availability"
echo "  Business Availability"
echo "  Business Error Budget"
echo
echo "APM:"
echo "  Calls       / SUM"
echo "  Error Rate  / MEAN"
echo "  Latency     / MEAN"
echo

#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/opt/instana-demo/instana-api"
STATE_DIR="${BASE_DIR}/state"
CONFIG_DIR="${BASE_DIR}/config"

DASHBOARD_TITLE="RETAIL - Critical Business Flow"
APP_NAME="RETAIL - Critical Promotions Flow"

USER_EMAIL="${DASHBOARD_USER_EMAIL:-admin@instana.local}"
TOKEN_NAME="${DASHBOARD_API_TOKEN_NAME:-demo}"

INSTANA_URL="${INSTANA_URL:-https://unit0-ibm.instana-0.ibmdte.local}"

mkdir -p "${STATE_DIR}" "${CONFIG_DIR}"


# ============================================================
# TOKEN
# ============================================================

if [[ -z "${INSTANA_TOKEN:-}" ]]; then
    IFS= read -rsp "Instana API Token: " INSTANA_TOKEN
    echo
fi

INSTANA_TOKEN="${INSTANA_TOKEN//$'\r'/}"

[[ -n "${INSTANA_TOKEN}" ]] || {
    echo "ERROR: Instana API Token vacío."
    exit 1
}


# ============================================================
# API HELPER
# ============================================================

api_call() {

    local method="$1"
    local path="$2"
    local payload="${3:-}"

    API_BODY=$(mktemp)

    if [[ -n "${payload}" ]]; then

        API_CODE=$(curl -skS \
            -o "${API_BODY}" \
            -w '%{http_code}' \
            -X "${method}" \
            -H "Authorization: apiToken ${INSTANA_TOKEN}" \
            -H "Accept: application/json" \
            -H "Content-Type: application/json" \
            --data @"${payload}" \
            "${INSTANA_URL}${path}")

    else

        API_CODE=$(curl -skS \
            -o "${API_BODY}" \
            -w '%{http_code}' \
            -X "${method}" \
            -H "Authorization: apiToken ${INSTANA_TOKEN}" \
            -H "Accept: application/json" \
            "${INSTANA_URL}${path}")

    fi
}


ensure_id() {

    local file="$1"

    if [[ ! -s "${file}" ]]; then

        tr -d '-' < /proc/sys/kernel/random/uuid \
          | cut -c1-16 \
          > "${file}"

    fi
}


echo
echo "======================================================"
echo " INSTANA - RETAIL CRITICAL BUSINESS FLOW DASHBOARD"
echo "======================================================"


# ============================================================
# 1 - DEPENDENCIES
# ============================================================

echo
echo "=== [1/8] Resolviendo dependencias ==="

for required_state in \
    slo-technical-id \
    slo-business-id
do

    if [[ ! -s "${STATE_DIR}/${required_state}" ]]; then
        echo "ERROR: falta state/${required_state}"
        exit 1
    fi

done


TECH_SLO_ID=$(cat "${STATE_DIR}/slo-technical-id")
BUS_SLO_ID=$(cat "${STATE_DIR}/slo-business-id")

echo "Technical SLO:"
echo "  ${TECH_SLO_ID}"

echo
echo "Business SLO:"
echo "  ${BUS_SLO_ID}"


# ============================================================
# 2 - USER
# ============================================================

echo
echo "=== [2/8] Resolviendo usuario ==="

api_call GET "/api/custom-dashboard/shareable-users"

[[ "${API_CODE}" == "200" ]] || {
    echo "ERROR HTTP=${API_CODE}"
    cat "${API_BODY}"
    exit 1
}


USER_ID=$(
    jq -r \
      --arg email "${USER_EMAIL}" \
      'first(
         (
           if type == "array"
           then .[]
           else (.items // [])[]
           end
         )
         |
         select(.email == $email)
         |
         .id
       ) // empty' \
      "${API_BODY}"
)

rm -f "${API_BODY}"


[[ -n "${USER_ID}" ]] || {
    echo "ERROR: usuario ${USER_EMAIL} no encontrado."
    exit 1
}

echo "${USER_EMAIL}"
echo "${USER_ID}"


# ============================================================
# 3 - SHAREABLE API TOKEN
# ============================================================

echo
echo "=== [3/8] Resolviendo API Token del Dashboard ==="

api_call GET "/api/custom-dashboard/shareable-api-tokens"

[[ "${API_CODE}" == "200" ]] || {
    echo "ERROR HTTP=${API_CODE}"
    cat "${API_BODY}"
    exit 1
}


TOKEN_ID=$(
    jq -r \
      --arg token_name "${TOKEN_NAME}" \
      'first(
         (
           if type == "array"
           then .[]
           else (.items // [])[]
           end
         )
         |
         select(.name == $token_name)
         |
         .id
       ) // empty' \
      "${API_BODY}"
)

rm -f "${API_BODY}"


[[ -n "${TOKEN_ID}" ]] || {
    echo "ERROR: API Token ${TOKEN_NAME} no encontrado."
    exit 1
}

echo "${TOKEN_NAME}"
echo "${TOKEN_ID}"


# ============================================================
# 4 - DASHBOARD
# ============================================================

echo
echo "=== [4/8] Resolviendo Dashboard ==="

DASHBOARD_ID=""


if [[ -s "${STATE_DIR}/dashboard-id" ]]; then

    CANDIDATE_ID=$(cat "${STATE_DIR}/dashboard-id")

    api_call GET \
      "/api/custom-dashboard/${CANDIDATE_ID}"

    if [[ "${API_CODE}" == "200" ]]; then

        FOUND_ID=$(
            jq -r '.id // empty' "${API_BODY}"
        )

        if [[ "${FOUND_ID}" == "${CANDIDATE_ID}" ]]; then
            DASHBOARD_ID="${CANDIDATE_ID}"
        fi

    fi

    rm -f "${API_BODY}"
fi


if [[ -z "${DASHBOARD_ID}" ]]; then

    api_call GET \
      "/api/custom-dashboard?query=RETAIL&page=1&pageSize=100&withTotalHits=true"

    [[ "${API_CODE}" == "200" ]] || {
        echo "ERROR HTTP=${API_CODE}"
        cat "${API_BODY}"
        exit 1
    }


    DASHBOARD_ID=$(
        jq -r \
          --arg dashboard_title "${DASHBOARD_TITLE}" \
          'first(
             (
               if type == "array"
               then .[]
               else (.items // [])[]
               end
             )
             |
             select(.title == $dashboard_title)
             |
             .id
           ) // empty' \
          "${API_BODY}"
    )

    rm -f "${API_BODY}"
fi


if [[ -n "${DASHBOARD_ID}" ]]; then

    echo "Dashboard existente:"
    echo "  ${DASHBOARD_ID}"

else

    echo "Dashboard no existe."
    echo "Será creado."

fi


# ============================================================
# 5 - WIDGET IDS
# ============================================================

echo
echo "=== [5/8] Preparando Widget IDs ==="


ensure_id \
  "${STATE_DIR}/widget-slo-technical-indicator-id"

ensure_id \
  "${STATE_DIR}/widget-slo-indicator-id"

ensure_id \
  "${STATE_DIR}/widget-slo-error-budget-id"

ensure_id \
  "${STATE_DIR}/widget-apm-calls-id"

ensure_id \
  "${STATE_DIR}/widget-apm-errors-id"

ensure_id \
  "${STATE_DIR}/widget-apm-latency-id"


TECH_WIDGET_ID=$(
  cat "${STATE_DIR}/widget-slo-technical-indicator-id"
)

BUS_WIDGET_ID=$(
  cat "${STATE_DIR}/widget-slo-indicator-id"
)

BUDGET_WIDGET_ID=$(
  cat "${STATE_DIR}/widget-slo-error-budget-id"
)

CALLS_WIDGET_ID=$(
  cat "${STATE_DIR}/widget-apm-calls-id"
)

ERRORS_WIDGET_ID=$(
  cat "${STATE_DIR}/widget-apm-errors-id"
)

LATENCY_WIDGET_ID=$(
  cat "${STATE_DIR}/widget-apm-latency-id"
)


echo "SLO Technical : ${TECH_WIDGET_ID}"
echo "SLO Business  : ${BUS_WIDGET_ID}"
echo "Error Budget  : ${BUDGET_WIDGET_ID}"

echo
echo "APM Calls     : ${CALLS_WIDGET_ID}"
echo "APM Errors    : ${ERRORS_WIDGET_ID}"
echo "APM Latency   : ${LATENCY_WIDGET_ID}"


# ============================================================
# 6 - BUILD CANONICAL DASHBOARD
# ============================================================

echo
echo "=== [6/8] Construyendo Dashboard declarativo ==="


jq -n \
  --arg dashboard_id "${DASHBOARD_ID}" \
  --arg dashboard_title "${DASHBOARD_TITLE}" \
  --arg user_id "${USER_ID}" \
  --arg token_id "${TOKEN_ID}" \
  --arg app_name "${APP_NAME}" \
  --arg tech_slo "${TECH_SLO_ID}" \
  --arg bus_slo "${BUS_SLO_ID}" \
  --arg tech_widget "${TECH_WIDGET_ID}" \
  --arg bus_widget "${BUS_WIDGET_ID}" \
  --arg budget_widget "${BUDGET_WIDGET_ID}" \
  --arg calls_widget "${CALLS_WIDGET_ID}" \
  --arg errors_widget "${ERRORS_WIDGET_ID}" \
  --arg latency_widget "${LATENCY_WIDGET_ID}" \
'
(
  if $dashboard_id == ""
  then {}
  else {id: $dashboard_id}
  end
)

+

{
  title: $dashboard_title,

  accessRules: [

    {
      accessType: "READ_WRITE",
      relationType: "USER",
      relatedId: $user_id
    },

    {
      accessType: "READ_WRITE",
      relationType: "API_TOKEN",
      relatedId: $token_id
    },

    {
      accessType: "READ",
      relationType: "GLOBAL",
      relatedId: ""
    }

  ],

  widgets: [

    # ========================================================
    # TECHNICAL SLO
    # ========================================================

    {
      id: $tech_widget,

      title:
        "RETAIL - Technical Availability - Indicator",

      type: "slo2",

      x: 0,
      y: 0,
      width: 6,
      height: 26,

      config: {
        sloId: $tech_slo,
        entityType: "synthetic",
        chartType: "INDICATOR"
      }
    },


    # ========================================================
    # BUSINESS SLO
    # ========================================================

    {
      id: $bus_widget,

      title:
        "RETAIL - Business Availability - Indicator",

      type: "slo2",

      x: 6,
      y: 0,
      width: 6,
      height: 26,

      config: {
        sloId: $bus_slo,
        entityType: "synthetic",
        chartType: "INDICATOR"
      }
    },


    # ========================================================
    # BUSINESS ERROR BUDGET
    # ========================================================

    {
      id: $budget_widget,

      title:
        "RETAIL - Business Availability - Error Budget",

      type: "slo2",

      x: 0,
      y: 26,
      width: 6,
      height: 26,

      config: {
        sloId: $bus_slo,
        entityType: "synthetic",
        chartType: "ERROR_BUDGET"
      }
    },


    # ========================================================
    # APM CALLS
    # ========================================================

    {
      id: $calls_widget,

      title:
        "RETAIL - APM Calls",

      type: "chart",

      x: 0,
      y: 52,
      width: 5,
      height: 15,

      config: {

        shareMaxAxisDomain: false,

        y1: {

          formatter: "number.detailed",

          renderer: "line",

          metrics: [

            {
              includeSynthetic: false,

              color: "",

              metric: "calls",

              timeShift: 0,

              tagFilterExpression: {

                name: "application.name",

                type: "TAG_FILTER",

                value: $app_name,

                entity: "DESTINATION",

                operator: "EQUALS"
              },

              metricLabel: "Calls",

              compareToTimeShifted: false,

              threshold: {
                critical: "",
                warning: "",
                thresholdEnabled: false,
                operator: ">="
              },

              aggregation: "SUM",

              label: "",

              source: "APPLICATION",

              includeInternal: false
            }

          ],

          formatterSelected: false
        },

        y2: {
          formatter: "number.detailed",
          renderer: "line",
          metrics: []
        },

        type: "TIME_SERIES"
      }
    },


    # ========================================================
    # APM ERROR RATE
    # ========================================================

    {
      id: $errors_widget,

      title:
        "RETAIL - APM Error Rate",

      type: "chart",

      x: 5,
      y: 52,
      width: 5,
      height: 15,

      config: {

        shareMaxAxisDomain: false,

        y1: {

          formatter:
            "percentage.detailed",

          renderer:
            "line",

          metrics: [

            {
              includeSynthetic: false,

              color: "",

              metric: "errors",

              timeShift: 0,

              tagFilterExpression: {

                name: "application.name",

                type: "TAG_FILTER",

                value: $app_name,

                entity: "DESTINATION",

                operator: "EQUALS"
              },

              metricLabel:
                "Erroneous calls (rate)",

              compareToTimeShifted: false,

              threshold: {
                critical: "",
                warning: "",
                thresholdEnabled: false,
                operator: ">="
              },

              aggregation: "MEAN",

              label: "",

              source: "APPLICATION",

              includeInternal: false
            }

          ],

          formatterSelected: false
        },

        y2: {
          formatter: "number.detailed",
          renderer: "line",
          metrics: []
        },

        type: "TIME_SERIES"
      }
    },


    # ========================================================
    # APM LATENCY
    # ========================================================

    {
      id: $latency_widget,

      title:
        "RETAIL - APM Latency (ms)",

      type: "chart",

      x: 0,
      y: 67,
      width: 5,
      height: 13,

      config: {

        shareMaxAxisDomain: false,

        y1: {

          formatter:
            "latency.detailed",

          renderer:
            "line",

          metrics: [

            {
              includeSynthetic: false,

              color: "",

              metric: "latency",

              timeShift: 0,

              tagFilterExpression: {

                name: "application.name",

                type: "TAG_FILTER",

                value: $app_name,

                entity: "DESTINATION",

                operator: "EQUALS"
              },

              metricLabel: "Latency",

              compareToTimeShifted: false,

              threshold: {
                critical: "",
                warning: "",
                thresholdEnabled: false,
                operator: ">="
              },

              aggregation: "MEAN",

              label: "",

              source: "APPLICATION",

              includeInternal: false
            }

          ],

          formatterSelected: false
        },

        y2: {
          formatter: "number.detailed",
          renderer: "line",
          metrics: []
        },

        type: "TIME_SERIES"
      }
    }

  ]
}
' > "${CONFIG_DIR}/dashboard-retail-final.json"


jq . \
  "${CONFIG_DIR}/dashboard-retail-final.json" \
  >/dev/null


echo "JSON=OK"
echo "Widgets=$(
  jq '.widgets | length' \
  "${CONFIG_DIR}/dashboard-retail-final.json"
)"


# ============================================================
# 7 - CREATE / UPDATE
# ============================================================

echo
echo "=== [7/8] Aplicando Dashboard ==="


if [[ -n "${DASHBOARD_ID}" ]]; then

    echo "Modo: UPDATE"

    api_call \
      PUT \
      "/api/custom-dashboard/${DASHBOARD_ID}" \
      "${CONFIG_DIR}/dashboard-retail-final.json"

else

    echo "Modo: CREATE"

    api_call \
      POST \
      "/api/custom-dashboard" \
      "${CONFIG_DIR}/dashboard-retail-final.json"

fi


echo "HTTP=${API_CODE}"


if [[ ! "${API_CODE}" =~ ^2 ]]; then

    echo
    echo "ERROR aplicando Dashboard:"
    cat "${API_BODY}"

    exit 1
fi


NEW_ID=$(
    jq -r '.id // empty' "${API_BODY}" \
    2>/dev/null || true
)


if [[ -n "${NEW_ID}" ]]; then
    DASHBOARD_ID="${NEW_ID}"
fi


rm -f "${API_BODY}"


# CREATE fallback
if [[ -z "${DASHBOARD_ID}" ]]; then

    api_call GET \
      "/api/custom-dashboard?query=RETAIL&page=1&pageSize=100&withTotalHits=true"

    DASHBOARD_ID=$(
        jq -r \
          --arg dashboard_title "${DASHBOARD_TITLE}" \
          'first(
             (
               if type == "array"
               then .[]
               else (.items // [])[]
               end
             )
             |
             select(.title == $dashboard_title)
             |
             .id
           ) // empty' \
          "${API_BODY}"
    )

    rm -f "${API_BODY}"
fi


[[ -n "${DASHBOARD_ID}" ]] || {
    echo "ERROR: no fue posible obtener Dashboard ID."
    exit 1
}


printf '%s\n' "${DASHBOARD_ID}" \
  > "${STATE_DIR}/dashboard-id"


# ============================================================
# 8 - READ BACK / VALIDATION
# ============================================================

echo
echo "=== [8/8] Validando Dashboard ==="


api_call GET \
  "/api/custom-dashboard/${DASHBOARD_ID}"


[[ "${API_CODE}" == "200" ]] || {

    echo "ERROR HTTP=${API_CODE}"
    cat "${API_BODY}"
    exit 1

}


cp "${API_BODY}" \
  "${CONFIG_DIR}/dashboard-retail-current.json"


jq '
{
  id,
  title,
  writable,

  widgetCount:
    (.widgets | length),

  widgets: [

    .widgets[] |

    {
      title,
      type,
      x,
      y,
      width,
      height,

      metric:
        (.config.y1.metrics[0].metric // null),

      aggregation:
        (.config.y1.metrics[0].aggregation // null),

      formatter:
        (.config.y1.formatter // null),

      sloId:
        (.config.sloId // null),

      chartType:
        (.config.type //
         .config.chartType //
         null)
    }

  ]
}
' "${API_BODY}"


# ============================================================
# FUNCTIONAL VALIDATION
# ============================================================

jq -e \
  --arg tech_slo "${TECH_SLO_ID}" \
  --arg bus_slo "${BUS_SLO_ID}" \
'

(.widgets | length) == 6

and

any(
  .widgets[];

  .type == "slo2"

  and
  .config.sloId == $tech_slo

  and
  .config.chartType == "INDICATOR"
)

and

any(
  .widgets[];

  .type == "slo2"

  and
  .config.sloId == $bus_slo

  and
  .config.chartType == "INDICATOR"
)

and

any(
  .widgets[];

  .type == "slo2"

  and
  .config.sloId == $bus_slo

  and
  .config.chartType == "ERROR_BUDGET"
)

and

any(
  .widgets[];

  .type == "chart"

  and
  .config.y1.metrics[0].metric == "calls"

  and
  .config.y1.metrics[0].aggregation == "SUM"

  and
  .config.y1.formatter == "number.detailed"
)

and

any(
  .widgets[];

  .type == "chart"

  and
  .config.y1.metrics[0].metric == "errors"

  and
  .config.y1.metrics[0].aggregation == "MEAN"

  and
  .config.y1.formatter == "percentage.detailed"
)

and

any(
  .widgets[];

  .type == "chart"

  and
  .config.y1.metrics[0].metric == "latency"

  and
  .config.y1.metrics[0].aggregation == "MEAN"

  and
  .config.y1.formatter == "latency.detailed"
)

and

any(
  .accessRules[];

  .relationType == "GLOBAL"

  and
  .accessType == "READ"
)

and

(
  [
    .widgets[] |
    select(
      (.title | contains("DISCOVERY"))
    )
  ]
  | length
) == 0

' "${API_BODY}" >/dev/null


rm -f "${API_BODY}"


echo
echo "======================================================"
echo " RETAIL BUSINESS DASHBOARD = PASS"
echo "======================================================"

echo
echo "Dashboard:"
echo "  ${DASHBOARD_TITLE}"

echo
echo "ID:"
echo "  ${DASHBOARD_ID}"

echo
echo "SLO:"
echo "  PASS  Technical Availability"
echo "  PASS  Business Availability"
echo "  PASS  Business Error Budget"

echo
echo "APM:"
echo "  PASS  Calls       / SUM  / number"
echo "  PASS  Error Rate  / MEAN / percentage"
echo "  PASS  Latency     / MEAN / latency"

echo
echo "Widgets:"
echo "  6"

echo
echo "Discovery widgets:"
echo "  0"

echo

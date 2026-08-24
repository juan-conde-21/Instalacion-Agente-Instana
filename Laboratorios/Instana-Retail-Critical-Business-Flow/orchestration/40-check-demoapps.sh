#!/usr/bin/env bash
set -uo pipefail

MODE="${1:---check}"

SSH_KEY="${SSH_KEY:-/home/admin/.ssh/id_rsa}"
DEMOAPPS_HOST="${DEMOAPPS_HOST:-192.168.252.33}"
DEMOAPPS_USER="${DEMOAPPS_USER:-jammer}"

if [[ "${MODE}" != "--check" ]]; then
    echo "Usage:"
    echo "  $0 --check"
    echo
    echo "Apply mode is not enabled yet."
    exit 2
fi

if [[ ! -f "${SSH_KEY}" ]]; then
    echo "[FAIL] SSH key missing: ${SSH_KEY}"
    exit 1
fi

exec ssh \
  -i "${SSH_KEY}" \
  -o BatchMode=yes \
  -o StrictHostKeyChecking=no \
  "${DEMOAPPS_USER}@${DEMOAPPS_HOST}" \
  'sudo -n bash -s' <<'REMOTE'

set -uo pipefail

K="k3s kubectl"

FAILURES=0
WARNINGS=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

ok() {
    printf "${GREEN}[OK]   ${RESET} %-36s %s\n" "$1" "${2:-}"
}

fail() {
    printf "${RED}[FAIL] ${RESET} %-36s %s\n" "$1" "${2:-}"
    FAILURES=$((FAILURES + 1))
}

warn() {
    printf "${YELLOW}[WARN] ${RESET} %-36s %s\n" "$1" "${2:-}"
    WARNINGS=$((WARNINGS + 1))
}

info() {
    printf "${CYAN}[INFO] ${RESET} %-36s %s\n" "$1" "${2:-}"
}

check_command() {

    if command -v "$1" >/dev/null 2>&1; then
        ok "Command $1" "AVAILABLE"
    else
        fail "Command $1" "MISSING"
    fi
}

http_get() {

    local label="$1"
    local url="$2"
    local body

    body=$(mktemp)

    local code

    code=$(
        curl -sS \
          --connect-timeout 5 \
          --max-time 10 \
          -o "${body}" \
          -w '%{http_code}' \
          "${url}" \
          2>/dev/null || true
    )

    if [[ "${code}" == "200" ]]; then
        ok "${label}" "HTTP 200"
    else
        fail "${label}" "HTTP ${code:-000}"
    fi

    HTTP_BODY_FILE="${body}"
    HTTP_CODE="${code}"
}

json_value() {

    local file="$1"
    local expression="$2"

    jq -r "${expression} // empty" "${file}" 2>/dev/null || true
}


echo
echo "========================================================"
echo " INSTANA RETAIL LAB - DEMO APPS"
echo "========================================================"
echo

info "Mode" "READ ONLY"


# ============================================================
# HOST
# ============================================================

if [[ "$(hostname)" == "demo-apps" ]]; then
    ok "Hostname" "demo-apps"
else
    fail "Hostname" "$(hostname)"
fi

if grep -q '^VERSION_ID="9.4"' /etc/os-release; then
    ok "Operating System" "RHEL 9.4"
else
    warn "Operating System" "$(grep '^PRETTY_NAME=' /etc/os-release)"
fi


# ============================================================
# TOOLS
# ============================================================

for cmd in \
    java \
    javac \
    mvn \
    buildah \
    helm \
    k3s \
    curl \
    jq \
    grep \
    stat
do
    check_command "${cmd}"
done


JAVA_VERSION="$(java -version 2>&1 | head -1 || true)"

if echo "${JAVA_VERSION}" | grep -q '"17\.'; then
    ok "Java" "${JAVA_VERSION}"
else
    fail "Java" "${JAVA_VERSION:-UNKNOWN}"
fi

if mvn -version 2>/dev/null \
   | head -1 \
   | grep -q 'Apache Maven 3.6.3'
then
    ok "Maven" "3.6.3"
else
    warn "Maven" "$(mvn -version 2>/dev/null | head -1)"
fi

if buildah --version 2>/dev/null \
   | grep -q '1.43.2'
then
    ok "Buildah" "1.43.2"
else
    warn "Buildah" "$(buildah --version 2>/dev/null)"
fi


# ============================================================
# K3S
# ============================================================

if systemctl is-enabled k3s >/dev/null 2>&1; then
    ok "K3s service" "ENABLED"
else
    fail "K3s service" "NOT ENABLED"
fi

if systemctl is-active k3s >/dev/null 2>&1; then
    ok "K3s service" "ACTIVE"
else
    fail "K3s service" "NOT ACTIVE"
fi

K3S_VERSION="$(k3s --version 2>/dev/null | head -1 || true)"

if echo "${K3S_VERSION}" | grep -q 'v1.33.2+k3s1'; then
    ok "K3s version" "v1.33.2+k3s1"
else
    warn "K3s version" "${K3S_VERSION}"
fi

NODE_READY="$(
    $K get node demo-apps \
      -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' \
      2>/dev/null || true
)"

if [[ "${NODE_READY}" == "True" ]]; then
    ok "K3s node" "READY"
else
    fail "K3s node" "${NODE_READY:-UNKNOWN}"
fi


# ============================================================
# USER / DIRECTORIES
# ============================================================

if getent passwd instanademo >/dev/null 2>&1; then
    ok "User instanademo" "PRESENT"
else
    fail "User instanademo" "MISSING"
fi

for d in \
    /opt/instana-demo \
    /opt/instana-demo/app \
    /opt/instana-demo/app/app \
    /opt/instana-demo/app/cache \
    /opt/instana-demo/app/src \
    /opt/instana-demo/k8s-retail
do
    if [[ -d "${d}" ]]; then
        ok "Directory" "${d}"
    else
        fail "Directory" "${d} MISSING"
    fi
done


# ============================================================
# RETAIL SOURCE
# ============================================================

POM="/opt/instana-demo/app/pom.xml"

PROPS="/opt/instana-demo/app/src/main/resources/application.properties"

JAVA_SRC="/opt/instana-demo/app/src/main/java/com/ibm/demo/retail/RetailApplication.java"

INDEX="/opt/instana-demo/app/src/main/resources/static/index.html"

JAR="/opt/instana-demo/app/app/retail-app.jar"


if [[ -f "${POM}" ]] \
   && grep -q '<version>3.5.16</version>' "${POM}" \
   && grep -q '<java.version>17</java.version>' "${POM}"
then
    ok "RETAIL pom.xml" "Spring Boot 3.5.16 / Java 17"
else
    fail "RETAIL pom.xml" "INVALID / MISSING"
fi


if [[ -f "${PROPS}" ]] \
   && grep -q '^server.port=18083$' "${PROPS}" \
   && grep -q '^demo.central.url=http://192.168.252.35:18082$' "${PROPS}" \
   && grep -q '^demo.max.age.seconds=120$' "${PROPS}"
then
    ok "RETAIL properties" "VALID"
else
    fail "RETAIL properties" "INVALID / MISSING"
fi


if [[ -f "${JAVA_SRC}" ]] \
   && grep -q '/api/sync' "${JAVA_SRC}" \
   && grep -q '/api/status' "${JAVA_SRC}" \
   && grep -q '/api/profiles' "${JAVA_SRC}" \
   && grep -q '/api/catalog' "${JAVA_SRC}" \
   && grep -q '/api/checkout' "${JAVA_SRC}" \
   && grep -q '/api/orders/{userId}' "${JAVA_SRC}" \
   && grep -q '/api/operation/{sku}' "${JAVA_SRC}" \
   && grep -q 'PROMOTIONS_FILE_STALE' "${JAVA_SRC}" \
   && grep -q 'event=checkout_success' "${JAVA_SRC}" \
   && grep -q 'event=checkout_rejected' "${JAVA_SRC}"
then
    ok "RETAIL Java source" "NOVA V4 / VALID"
else
    fail "RETAIL Java source" "INVALID / MISSING"
fi


if [[ -f "${INDEX}" ]] \
   && grep -q 'name="instana-demo-app" content="nova-market"' "${INDEX}" \
   && grep -q 'name="instana-demo-version" content="4"' "${INDEX}" \
   && grep -q '/api/profiles' "${INDEX}" \
   && grep -q '/api/catalog' "${INDEX}" \
   && grep -q '/api/checkout' "${INDEX}" \
   && grep -q '/api/orders/' "${INDEX}" \
   && grep -q 'checkout-success' "${INDEX}" \
   && grep -q 'checkout-error' "${INDEX}"
then
    ok "RETAIL web UI" "NOVA V4 / VALID"
else
    fail "RETAIL web UI" "INVALID / MISSING"
fi


if [[ -f "${JAR}" ]]; then

    JAR_SIZE="$(stat -c%s "${JAR}")"

    if (( JAR_SIZE > 20000000 )); then
        ok "RETAIL JAR" "${JAR_SIZE} bytes"
    else
        fail "RETAIL JAR" "${JAR_SIZE} bytes"
    fi

else
    fail "RETAIL JAR" "MISSING"
fi


# ============================================================
# CONTAINERFILE / IMAGE
# ============================================================

CONTAINERFILE="/opt/instana-demo/k8s-retail/Containerfile"

if [[ -f "${CONTAINERFILE}" ]] \
   && grep -q 'ubi9/openjdk-17-runtime' "${CONTAINERFILE}" \
   && grep -q 'EXPOSE 18083' "${CONTAINERFILE}" \
   && grep -q 'retail-app.jar' "${CONTAINERFILE}"
then
    ok "RETAIL Containerfile" "VALID"
else
    fail "RETAIL Containerfile" "INVALID / MISSING"
fi


if k3s ctr images list -q 2>/dev/null \
   | grep -Fx 'docker.io/library/instana-demo-retail:1.0' >/dev/null
then
    ok "RETAIL local image" "docker.io/library/instana-demo-retail:1.0"
else
    fail "RETAIL local image" "MISSING"
fi


# ============================================================
# RETAIL KUBERNETES
# ============================================================

NS_PHASE="$(
    $K get namespace instana-critical-demo \
      -o jsonpath='{.status.phase}' \
      2>/dev/null || true
)"

if [[ "${NS_PHASE}" == "Active" ]]; then
    ok "Retail namespace" "ACTIVE"
else
    fail "Retail namespace" "${NS_PHASE:-MISSING}"
fi


DEP_READY="$(
    $K -n instana-critical-demo \
      get deployment retail-app \
      -o jsonpath='{.status.readyReplicas}' \
      2>/dev/null || true
)"

if [[ "${DEP_READY}" == "1" ]]; then
    ok "RETAIL deployment" "1/1 READY"
else
    fail "RETAIL deployment" "${DEP_READY:-0}/1 READY"
fi


RETAIL_IMAGE="$(
    $K -n instana-critical-demo \
      get deployment retail-app \
      -o jsonpath='{.spec.template.spec.containers[0].image}' \
      2>/dev/null || true
)"

if [[ "${RETAIL_IMAGE}" == "docker.io/library/instana-demo-retail:1.0" ]]; then
    ok "RETAIL deployment image" "${RETAIL_IMAGE}"
else
    fail "RETAIL deployment image" "${RETAIL_IMAGE:-MISSING}"
fi


RETAIL_STRATEGY="$(
    $K -n instana-critical-demo \
      get deployment retail-app \
      -o jsonpath='{.spec.strategy.type}' \
      2>/dev/null || true
)"

if [[ "${RETAIL_STRATEGY}" == "Recreate" ]]; then
    ok "RETAIL deployment strategy" "Recreate"
else
    fail "RETAIL deployment strategy" "${RETAIL_STRATEGY:-UNKNOWN}"
fi


PULL_POLICY="$(
    $K -n instana-critical-demo \
      get deployment retail-app \
      -o jsonpath='{.spec.template.spec.containers[0].imagePullPolicy}' \
      2>/dev/null || true
)"

if [[ "${PULL_POLICY}" == "Never" ]]; then
    ok "RETAIL imagePullPolicy" "Never"
else
    fail "RETAIL imagePullPolicy" "${PULL_POLICY:-UNKNOWN}"
fi


HOST_PORT="$(
    $K -n instana-critical-demo \
      get deployment retail-app \
      -o jsonpath='{.spec.template.spec.containers[0].ports[0].hostPort}' \
      2>/dev/null || true
)"

if [[ "${HOST_PORT}" == "18083" ]]; then
    ok "RETAIL hostPort" "18083"
else
    fail "RETAIL hostPort" "${HOST_PORT:-MISSING}"
fi


CENTRAL_ENV="$(
    $K -n instana-critical-demo \
      get deployment retail-app \
      -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="DEMO_CENTRAL_URL")].value}' \
      2>/dev/null || true
)"

if [[ "${CENTRAL_ENV}" == "http://192.168.252.35:18082" ]]; then
    ok "RETAIL CENTRAL target" "${CENTRAL_ENV}"
else
    fail "RETAIL CENTRAL target" "${CENTRAL_ENV:-MISSING}"
fi


SERVICE_PORT="$(
    $K -n instana-critical-demo \
      get service retail-app \
      -o jsonpath='{.spec.ports[0].port}' \
      2>/dev/null || true
)"

if [[ "${SERVICE_PORT}" == "18083" ]]; then
    ok "RETAIL Service" "18083"
else
    fail "RETAIL Service" "${SERVICE_PORT:-MISSING}"
fi


# ============================================================
# CENTRAL CONNECTIVITY
# ============================================================

http_get \
  "CENTRAL from demo-apps" \
  "http://192.168.252.35:18082/health"

rm -f "${HTTP_BODY_FILE}"


# ============================================================
# RETAIL FUNCTIONAL VALIDATION
# ============================================================

http_get \
  "RETAIL technical health" \
  "http://127.0.0.1:18083/health"

if [[ "${HTTP_CODE}" == "200" ]] \
   && [[ "$(json_value "${HTTP_BODY_FILE}" '.status')" == "UP" ]]
then
    ok "RETAIL technical state" "UP"
else
    fail "RETAIL technical state" "NOT UP"
fi

rm -f "${HTTP_BODY_FILE}"


http_get \
  "RETAIL business status" \
  "http://127.0.0.1:18083/api/status"

STATUS="$(
    json_value "${HTTP_BODY_FILE}" '.status'
)"

RECORDS="$(
    json_value "${HTTP_BODY_FILE}" '.records'
)"

MAX_AGE="$(
    json_value "${HTTP_BODY_FILE}" '.maxAgeSeconds'
)"

AGE="$(
    json_value "${HTTP_BODY_FILE}" '.ageSeconds'
)"

if [[ "${STATUS}" == "READY" ]]; then
    ok "RETAIL functional state" "READY"
else
    fail "RETAIL functional state" "${STATUS:-UNKNOWN}"
fi

if [[ "${RECORDS}" == "5000" ]]; then
    ok "RETAIL loaded records" "5000"
else
    fail "RETAIL loaded records" "${RECORDS:-UNKNOWN}"
fi

if [[ "${MAX_AGE}" == "120" ]]; then
    ok "RETAIL max file age" "120 seconds"
else
    fail "RETAIL max file age" "${MAX_AGE:-UNKNOWN}"
fi

if [[ "${AGE}" =~ ^[0-9]+$ ]] && (( AGE <= 120 )); then
    ok "RETAIL current file age" "${AGE}s"
else
    fail "RETAIL current file age" "${AGE:-UNKNOWN}s"
fi

rm -f "${HTTP_BODY_FILE}"


http_get \
  "RETAIL business operation" \
  "http://127.0.0.1:18083/api/operation/P00001"

OP_STATUS="$(
    json_value "${HTTP_BODY_FILE}" '.status'
)"

OP_SKU="$(
    json_value "${HTTP_BODY_FILE}" '.sku'
)"

if [[ "${HTTP_CODE}" == "200" ]] \
   && [[ "${OP_STATUS}" == "SUCCESS" ]] \
   && [[ "${OP_SKU}" == "P00001" ]]
then
    ok "Business transaction" "SUCCESS / P00001"
else
    fail "Business transaction" "${OP_STATUS:-FAILED}"
fi

rm -f "${HTTP_BODY_FILE}"


# ============================================================
# OTEL RETAIL
# ============================================================

for resource in \
    "serviceaccount/otel-retail-logs" \
    "daemonset/otel-retail-logs" \
    "configmap/otel-retail-logs"
do

    if $K -n instana-critical-demo \
       get "${resource}" \
       >/dev/null 2>&1
    then
        ok "OTel resource" "${resource}"
    else
        fail "OTel resource" "${resource} MISSING"
    fi
done


if $K get clusterrole otel-retail-logs >/dev/null 2>&1; then
    ok "OTel ClusterRole" "PRESENT"
else
    fail "OTel ClusterRole" "MISSING"
fi


if $K get clusterrolebinding otel-retail-logs >/dev/null 2>&1; then
    ok "OTel ClusterRoleBinding" "PRESENT"
else
    fail "OTel ClusterRoleBinding" "MISSING"
fi


OTEL_READY="$(
    $K -n instana-critical-demo \
      get daemonset otel-retail-logs \
      -o jsonpath='{.status.numberReady}' \
      2>/dev/null || true
)"

OTEL_DESIRED="$(
    $K -n instana-critical-demo \
      get daemonset otel-retail-logs \
      -o jsonpath='{.status.desiredNumberScheduled}' \
      2>/dev/null || true
)"

if [[ "${OTEL_READY}" == "1" ]] \
   && [[ "${OTEL_DESIRED}" == "1" ]]
then
    ok "OTel Retail DaemonSet" "1/1 READY"
else
    fail "OTel Retail DaemonSet" "${OTEL_READY:-0}/${OTEL_DESIRED:-0}"
fi


OTEL_IMAGE="$(
    $K -n instana-critical-demo \
      get daemonset otel-retail-logs \
      -o jsonpath='{.spec.template.spec.containers[0].image}' \
      2>/dev/null || true
)"

if [[ "${OTEL_IMAGE}" == "otel/opentelemetry-collector-contrib:0.157.0" ]]; then
    ok "OTel Retail image" "0.157.0"
else
    fail "OTel Retail image" "${OTEL_IMAGE:-UNKNOWN}"
fi


OTEL_CONFIG="$(
    $K -n instana-critical-demo \
      get configmap otel-retail-logs \
      -o jsonpath='{.data.otel-config\.yaml}' \
      2>/dev/null || true
)"

if echo "${OTEL_CONFIG}" \
   | grep -q '/var/log/pods/instana-critical-demo_retail-app-'
then
    ok "OTel Retail log source" "Retail pod logs"
else
    fail "OTel Retail log source" "INVALID"
fi

if echo "${OTEL_CONFIG}" \
   | grep -q 'endpoint: instana-agent.instana-agent:4317'
then
    ok "OTel -> Instana" "instana-agent:4317"
else
    fail "OTel -> Instana" "INVALID"
fi

if echo "${OTEL_CONFIG}" \
   | grep -q 'value: retail-app'
then
    ok "OTel service.name" "retail-app"
else
    fail "OTel service.name" "MISSING"
fi


# ============================================================
# INSTANA KUBERNETES
# ============================================================

INSTANA_DS_READY="$(
    $K -n instana-agent \
      get daemonset instana-agent \
      -o jsonpath='{.status.numberReady}' \
      2>/dev/null || true
)"

if [[ "${INSTANA_DS_READY}" == "1" ]]; then
    ok "Instana Agent DaemonSet" "1/1 READY"
else
    fail "Instana Agent DaemonSet" "${INSTANA_DS_READY:-0}/1"
fi


K8SENSOR_READY="$(
    $K -n instana-agent \
      get deployment instana-agent-k8sensor \
      -o jsonpath='{.status.readyReplicas}' \
      2>/dev/null || true
)"

K8SENSOR_REPLICAS="$(
    $K -n instana-agent \
      get deployment instana-agent-k8sensor \
      -o jsonpath='{.spec.replicas}' \
      2>/dev/null || true
)"

if [[ "${K8SENSOR_READY}" == "1" ]] \
   && [[ "${K8SENSOR_REPLICAS}" == "1" ]]
then
    ok "Instana K8Sensor" "1/1 READY"
else
    fail "Instana K8Sensor" "${K8SENSOR_READY:-0}/${K8SENSOR_REPLICAS:-0}"
fi


CONTROLLER_READY="$(
    $K -n instana-agent \
      get deployment instana-agent-controller-manager \
      -o jsonpath='{.status.readyReplicas}' \
      2>/dev/null || true
)"

if [[ "${CONTROLLER_READY}" == "1" ]]; then
    ok "Instana Operator" "1/1 READY"
else
    fail "Instana Operator" "${CONTROLLER_READY:-0}/1"
fi


INSTANA_OTLP_PORT="$(
    $K -n instana-agent \
      get service instana-agent \
      -o jsonpath='{.spec.ports[?(@.port==4317)].port}' \
      2>/dev/null || true
)"

if [[ "${INSTANA_OTLP_PORT}" == "4317" ]]; then
    ok "Instana OTLP service" "4317"
else
    fail "Instana OTLP service" "MISSING"
fi


# ============================================================
# SYNTHETIC POP
# ============================================================

SYN_NS="$(
    $K get namespace instana-synthetic \
      -o jsonpath='{.status.phase}' \
      2>/dev/null || true
)"

if [[ "${SYN_NS}" == "Active" ]]; then
    ok "Synthetic namespace" "ACTIVE"
else
    fail "Synthetic namespace" "${SYN_NS:-MISSING}"
fi


HELM_STATUS="$(
    $K -n instana-synthetic \
      get secret sh.helm.release.v1.synthetic-pop.v1 \
      -o jsonpath='{.metadata.labels.status}' \
      2>/dev/null || true
)"

if [[ "${HELM_STATUS}" == "deployed" ]]; then
    ok "Synthetic Helm release" "DEPLOYED"
else
    fail "Synthetic Helm release" "${HELM_STATUS:-MISSING}"
fi


SYN_DEPLOYMENTS="$(
    $K -n instana-synthetic \
      get deployments \
      -l app=synthetic-pop \
      --no-headers \
      2>/dev/null \
      | wc -l
)"

if [[ "${SYN_DEPLOYMENTS}" == "5" ]]; then
    ok "Synthetic playback/controller" "5 deployments"
else
    warn "Synthetic playback/controller" "${SYN_DEPLOYMENTS} deployments"
fi


for deployment in \
    synthetic-pop-controller \
    synthetic-pop-browserscript-playback-engine \
    synthetic-pop-http-playback-engine \
    synthetic-pop-ism-playback-engine \
    synthetic-pop-javascript-playback-engine \
    synthetic-pop-redis
do

    READY="$(
        $K -n instana-synthetic \
          get deployment "${deployment}" \
          -o jsonpath='{.status.readyReplicas}' \
          2>/dev/null || true
    )"

    if [[ "${READY}" == "1" ]]; then
        ok "Synthetic component" "${deployment} 1/1"
    else
        fail "Synthetic component" "${deployment} ${READY:-0}/1"
    fi
done


for secret in \
    instana-io \
    synthetic-pop-instana-key \
    synthetic-pop-redis
do

    if $K -n instana-synthetic \
       get secret "${secret}" \
       >/dev/null 2>&1
    then
        ok "Synthetic secret" "${secret} PRESENT"
    else
        fail "Synthetic secret" "${secret} MISSING"
    fi
done


# ============================================================
# OPTIONAL HELM VISIBILITY
# ============================================================

HELM_RELEASE="$(
    helm \
      --kubeconfig /etc/rancher/k3s/k3s.yaml \
      list \
      -n instana-synthetic \
      --no-headers \
      2>/dev/null \
      | awk '$1=="synthetic-pop" {print $1}' \
      || true
)"

if [[ "${HELM_RELEASE}" == "synthetic-pop" ]]; then
    ok "Helm CLI release visibility" "synthetic-pop"
else
    warn "Helm CLI release visibility" "release secret exists; CLI listing unavailable"
fi


# ============================================================
# RESULT
# ============================================================

echo
echo "========================================================"

if (( FAILURES == 0 )); then
    echo " DEMO APPS CHECK = READY"
else
    echo " DEMO APPS CHECK = FAILED"
fi

echo "========================================================"
echo
echo "Failures : ${FAILURES}"
echo "Warnings : ${WARNINGS}"
echo

exit "${FAILURES}"

REMOTE

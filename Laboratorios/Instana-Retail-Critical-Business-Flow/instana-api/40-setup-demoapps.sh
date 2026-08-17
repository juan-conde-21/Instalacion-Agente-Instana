#!/usr/bin/env bash
set -euo pipefail

MODE="${1:---check}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK_SCRIPT="${SCRIPT_DIR}/40-check-demoapps.sh"

ASSET_DIR="/opt/instana-demo/orchestration/assets/demoapps"

SSH_KEY="${SSH_KEY:-/home/admin/.ssh/id_rsa}"
DEMOAPPS_HOST="${DEMOAPPS_HOST:-192.168.252.33}"
DEMOAPPS_USER="${DEMOAPPS_USER:-jammer}"

REMOTE="${DEMOAPPS_USER}@${DEMOAPPS_HOST}"

case "${MODE}" in

    --check)
        exec "${CHECK_SCRIPT}" --check
        ;;

    --apply)
        ;;

    *)
        echo "Usage:"
        echo "  $0 --check"
        echo "  $0 --apply"
        exit 2
        ;;

esac


echo
echo "========================================================"
echo " INSTANA RETAIL LAB - DEMO APPS APPLY"
echo "========================================================"
echo


# ------------------------------------------------------------
# LOCAL PRECHECK
# ------------------------------------------------------------

[[ -x "${CHECK_SCRIPT}" ]] || {
    echo "[FAIL] Missing ${CHECK_SCRIPT}"
    exit 1
}

[[ -f "${SSH_KEY}" ]] || {
    echo "[FAIL] Missing SSH key ${SSH_KEY}"
    exit 1
}

[[ -d "${ASSET_DIR}" ]] || {
    echo "[FAIL] Missing asset directory ${ASSET_DIR}"
    exit 1
}

[[ -f "${ASSET_DIR}/SHA256SUMS" ]] || {
    echo "[FAIL] Missing SHA256SUMS"
    exit 1
}


echo "[INFO] Validating canonical assets..."

(
    cd "${ASSET_DIR}"
    sha256sum -c SHA256SUMS
)

echo "[OK] Canonical assets valid"


# ------------------------------------------------------------
# STAGE ASSETS ON DEMO-APPS
# ------------------------------------------------------------

echo
echo "[INFO] Staging canonical assets on demo-apps..."

tar \
  -C "${ASSET_DIR}" \
  -cf - \
  app \
  k8s-retail \
  SHA256SUMS \
| ssh \
    -i "${SSH_KEY}" \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=no \
    "${REMOTE}" \
    'sudo -n bash -c "
        rm -rf /tmp/instana-demo-40-assets
        mkdir -p /tmp/instana-demo-40-assets
        tar -C /tmp/instana-demo-40-assets -xf -
    "'

echo "[OK] Assets staged"


# ------------------------------------------------------------
# REMOTE APPLY
# ------------------------------------------------------------

ssh \
  -i "${SSH_KEY}" \
  -o BatchMode=yes \
  -o StrictHostKeyChecking=no \
  "${REMOTE}" \
  'sudo -n bash -s' <<'REMOTE_APPLY'

set -euo pipefail

K="k3s kubectl"

STAGE="/tmp/instana-demo-40-assets"

BASE="/opt/instana-demo"
APP="${BASE}/app"
K8S_DIR="${BASE}/k8s-retail"

IMAGE="docker.io/library/instana-demo-retail:1.0"


SOURCE_CHANGED=0
CONTAINER_CHANGED=0
RETAIL_FILE_CHANGED=0
OTEL_FILE_CHANGED=0

MAVEN_BUILD=0
IMAGE_BUILD=0

RETAIL_K8S_APPLY=0
RETAIL_ROLLOUT=0

OTEL_K8S_APPLY=0
OTEL_ROLLOUT=0

NAMESPACE_CREATED=0


ok() {
    printf '[OK]    %-36s %s\n' "$1" "${2:-}"
}

info() {
    printf '[INFO]  %-36s %s\n' "$1" "${2:-}"
}

fail() {
    printf '[FAIL]  %-36s %s\n' "$1" "${2:-}"
    exit 1
}


echo
echo "========================================================"
echo " DEMO APPS - REMOTE APPLY"
echo "========================================================"
echo


# ------------------------------------------------------------
# VERIFY STAGED ASSETS
# ------------------------------------------------------------

(
    cd "${STAGE}"
    sha256sum -c SHA256SUMS >/dev/null
)

ok "Staged assets" "SHA256 VALID"


# ------------------------------------------------------------
# PREREQUISITES
# ------------------------------------------------------------

for cmd in \
    java \
    javac \
    mvn \
    buildah \
    k3s \
    curl \
    jq \
    sha256sum
do

    command -v "${cmd}" >/dev/null 2>&1 \
        || fail "Prerequisite" "${cmd} MISSING"

done

ok "Build/runtime prerequisites" "PRESENT"


if ! systemctl is-active --quiet k3s
then
    fail "K3s" "NOT ACTIVE"
fi

ok "K3s" "ACTIVE"


# Instana is currently a prerequisite for Phase 40.

if ! ${K} -n instana-agent \
    get service instana-agent \
    >/dev/null 2>&1
then
    fail "Instana Agent" "SERVICE MISSING"
fi

ok "Instana Agent prerequisite" "PRESENT"


# ------------------------------------------------------------
# USER / DIRECTORY STRUCTURE
# ------------------------------------------------------------

if ! id instanademo >/dev/null 2>&1
then
    useradd \
      --system \
      --home-dir "${BASE}" \
      --shell /sbin/nologin \
      instanademo

    info "User instanademo" "CREATED"
else
    ok "User instanademo" "PRESENT"
fi


install -d \
  -o instanademo \
  -g instanademo \
  -m 755 \
  "${BASE}" \
  "${APP}" \
  "${APP}/app" \
  "${APP}/cache" \
  "${APP}/src" \
  "${APP}/src/main" \
  "${APP}/src/main/java" \
  "${APP}/src/main/java/com" \
  "${APP}/src/main/java/com/ibm" \
  "${APP}/src/main/java/com/ibm/demo" \
  "${APP}/src/main/java/com/ibm/demo/retail" \
  "${APP}/src/main/resources" \
  "${APP}/src/main/resources/static"


install -d \
  -o root \
  -g root \
  -m 755 \
  "${K8S_DIR}"


# ------------------------------------------------------------
# COPY HELPERS
# ------------------------------------------------------------

sync_app_file() {

    local src="$1"
    local dst="$2"

    if [[ -f "${dst}" ]] && cmp -s "${src}" "${dst}"
    then
        ok "Source" "${dst} UNCHANGED"
        return
    fi

    install \
      -o instanademo \
      -g instanademo \
      -m 644 \
      "${src}" \
      "${dst}"

    SOURCE_CHANGED=1

    info "Source" "${dst} UPDATED"
}


sync_root_file() {

    local src="$1"
    local dst="$2"
    local type="$3"

    if [[ -f "${dst}" ]] && cmp -s "${src}" "${dst}"
    then
        ok "${type}" "${dst} UNCHANGED"
        return
    fi

    install \
      -o root \
      -g root \
      -m 644 \
      "${src}" \
      "${dst}"

    case "${type}" in
        CONTAINERFILE)
            CONTAINER_CHANGED=1
            ;;
        RETAIL_MANIFEST)
            RETAIL_FILE_CHANGED=1
            ;;
        OTEL_MANIFEST)
            OTEL_FILE_CHANGED=1
            ;;
    esac

    info "${type}" "${dst} UPDATED"
}


# ------------------------------------------------------------
# SYNCHRONIZE SOURCE
# ------------------------------------------------------------

sync_app_file \
  "${STAGE}/app/pom.xml" \
  "${APP}/pom.xml"


sync_app_file \
  "${STAGE}/app/src/main/java/com/ibm/demo/retail/RetailApplication.java" \
  "${APP}/src/main/java/com/ibm/demo/retail/RetailApplication.java"


sync_app_file \
  "${STAGE}/app/src/main/resources/application.properties" \
  "${APP}/src/main/resources/application.properties"


sync_app_file \
  "${STAGE}/app/src/main/resources/static/index.html" \
  "${APP}/src/main/resources/static/index.html"


sync_root_file \
  "${STAGE}/k8s-retail/Containerfile" \
  "${K8S_DIR}/Containerfile" \
  "CONTAINERFILE"


sync_root_file \
  "${STAGE}/k8s-retail/retail-k8s.yaml" \
  "${K8S_DIR}/retail-k8s.yaml" \
  "RETAIL_MANIFEST"


sync_root_file \
  "${STAGE}/k8s-retail/otel-retail.yaml" \
  "${K8S_DIR}/otel-retail.yaml" \
  "OTEL_MANIFEST"


# ------------------------------------------------------------
# MAVEN BUILD
# ------------------------------------------------------------

JAR="${APP}/app/retail-app.jar"

if (( SOURCE_CHANGED == 1 )) || [[ ! -s "${JAR}" ]]
then

    echo
    info "Maven build" "REQUIRED"

    sudo -u instanademo \
      mvn \
      -q \
      -f "${APP}/pom.xml" \
      clean package \
      -DskipTests

    BUILT_JAR="${APP}/target/retail-app.jar"

    [[ -s "${BUILT_JAR}" ]] \
        || fail "Maven build" "JAR NOT CREATED"

    install \
      -o instanademo \
      -g instanademo \
      -m 644 \
      "${BUILT_JAR}" \
      "${JAR}"

    MAVEN_BUILD=1

    ok "Maven build" "$(stat -c%s "${JAR}") bytes"

else

    ok "Maven build" "NOT REQUIRED"

fi


# Keep image build context synchronized.

if [[ ! -f "${K8S_DIR}/retail-app.jar" ]] \
   || ! cmp -s "${JAR}" "${K8S_DIR}/retail-app.jar"
then

    install \
      -o root \
      -g root \
      -m 644 \
      "${JAR}" \
      "${K8S_DIR}/retail-app.jar"

    IMAGE_BUILD=1

    info "Image build context JAR" "UPDATED"

else

    ok "Image build context JAR" "UNCHANGED"

fi


# ------------------------------------------------------------
# IMAGE BUILD / IMPORT
# ------------------------------------------------------------

IMAGE_EXISTS=0

if k3s ctr images list -q 2>/dev/null \
   | grep -Fx "${IMAGE}" >/dev/null
then
    IMAGE_EXISTS=1
fi


if (( MAVEN_BUILD == 1 )) \
   || (( CONTAINER_CHANGED == 1 )) \
   || (( IMAGE_BUILD == 1 )) \
   || (( IMAGE_EXISTS == 0 ))
then

    echo
    info "Container image build" "REQUIRED"

    cd "${K8S_DIR}"

    buildah bud \
      -t "${IMAGE}" \
      -f Containerfile \
      .

    ARCHIVE="/tmp/instana-demo-retail-$$.tar"

    rm -f "${ARCHIVE}"

    buildah push \
      --format docker \
      "${IMAGE}" \
      "docker-archive:${ARCHIVE}:${IMAGE}"

    k3s ctr images import "${ARCHIVE}"

    rm -f "${ARCHIVE}"

    k3s ctr images list -q \
      | grep -Fx "${IMAGE}" >/dev/null \
      || fail "Container image" "IMPORT FAILED"

    IMAGE_BUILD=1

    ok "Container image" "${IMAGE}"

else

    IMAGE_BUILD=0

    ok "Container image build" "NOT REQUIRED"

fi


# ------------------------------------------------------------
# NAMESPACE
# ------------------------------------------------------------

if ! ${K} get namespace instana-critical-demo \
    >/dev/null 2>&1
then

    ${K} create namespace instana-critical-demo

    NAMESPACE_CREATED=1

    info "Retail namespace" "CREATED"

else

    ok "Retail namespace" "PRESENT"

fi


# ------------------------------------------------------------
# KUBERNETES DIFF HELPER
# ------------------------------------------------------------

k8s_diff_state() {

    local manifest="$1"
    local output="$2"

    set +e

    ${K} diff \
      -f "${manifest}" \
      >"${output}" \
      2>&1

    local rc=$?

    set -e

    case "${rc}" in

        0)
            return 0
            ;;

        1)
            return 1
            ;;

        *)
            cat "${output}"
            return 2
            ;;

    esac
}


# ------------------------------------------------------------
# RETAIL KUBERNETES
# ------------------------------------------------------------

RETAIL_DIFF="/tmp/retail-k8s.diff"

if k8s_diff_state \
    "${K8S_DIR}/retail-k8s.yaml" \
    "${RETAIL_DIFF}"
then

    ok "RETAIL Kubernetes" "NO DRIFT"

else

    RC=$?

    if [[ "${RC}" == "1" ]]
    then

        info "RETAIL Kubernetes" "DRIFT DETECTED"

        ${K} apply \
          -f "${K8S_DIR}/retail-k8s.yaml"

        RETAIL_K8S_APPLY=1

        ok "RETAIL Kubernetes" "APPLIED"

    else

        fail "RETAIL Kubernetes diff" "FAILED"

    fi

fi

rm -f "${RETAIL_DIFF}"


# A rebuilt image uses the same immutable demo tag.
# Restart only when image content actually changed.

if (( IMAGE_BUILD == 1 ))
then

    ${K} \
      -n instana-critical-demo \
      rollout restart deployment/retail-app

    RETAIL_ROLLOUT=1

    info "RETAIL rollout" "IMAGE CHANGED"

fi


if (( RETAIL_K8S_APPLY == 1 )) \
   || (( RETAIL_ROLLOUT == 1 )) \
   || (( NAMESPACE_CREATED == 1 ))
then

    ${K} \
      -n instana-critical-demo \
      rollout status deployment/retail-app \
      --timeout=180s

    ok "RETAIL rollout" "READY"

else

    ok "RETAIL rollout" "NOT REQUIRED"

fi


# ------------------------------------------------------------
# OTEL KUBERNETES
# ------------------------------------------------------------

OTEL_DIFF="/tmp/otel-k8s.diff"

if k8s_diff_state \
    "${K8S_DIR}/otel-retail.yaml" \
    "${OTEL_DIFF}"
then

    ok "OTel Kubernetes" "NO DRIFT"

else

    RC=$?

    if [[ "${RC}" == "1" ]]
    then

        info "OTel Kubernetes" "DRIFT DETECTED"

        ${K} apply \
          -f "${K8S_DIR}/otel-retail.yaml"

        OTEL_K8S_APPLY=1

        ok "OTel Kubernetes" "APPLIED"

    else

        fail "OTel Kubernetes diff" "FAILED"

    fi

fi

rm -f "${OTEL_DIFF}"


# ConfigMap changes do not restart the collector automatically.
# Restart only if some OTel declarative state changed.

if (( OTEL_K8S_APPLY == 1 ))
then

    ${K} \
      -n instana-critical-demo \
      rollout restart daemonset/otel-retail-logs

    OTEL_ROLLOUT=1

    ${K} \
      -n instana-critical-demo \
      rollout status daemonset/otel-retail-logs \
      --timeout=180s

    ok "OTel rollout" "READY"

else

    ok "OTel rollout" "NOT REQUIRED"

fi


# ------------------------------------------------------------
# WAIT FOR RETAIL BUSINESS OPERATION
# ------------------------------------------------------------

echo
info "Business readiness" "WAITING"


BUSINESS_READY=0

for i in $(seq 1 180)
do

    HEALTH_CODE="$(
        curl \
          -s \
          -o /tmp/retail-health.json \
          -w '%{http_code}' \
          --connect-timeout 2 \
          --max-time 5 \
          http://127.0.0.1:18083/health \
          2>/dev/null \
          || true
    )"

    STATUS_CODE="$(
        curl \
          -s \
          -o /tmp/retail-status.json \
          -w '%{http_code}' \
          --connect-timeout 2 \
          --max-time 5 \
          http://127.0.0.1:18083/api/status \
          2>/dev/null \
          || true
    )"

    OP_CODE="$(
        curl \
          -s \
          -o /tmp/retail-operation.json \
          -w '%{http_code}' \
          --connect-timeout 2 \
          --max-time 5 \
          http://127.0.0.1:18083/api/operation/P00001 \
          2>/dev/null \
          || true
    )"

    HEALTH_STATUS="$(
        jq -r '.status // empty' \
          /tmp/retail-health.json \
          2>/dev/null \
          || true
    )"

    FUNCTIONAL_STATUS="$(
        jq -r '.status // empty' \
          /tmp/retail-status.json \
          2>/dev/null \
          || true
    )"

    OP_STATUS="$(
        jq -r '.status // empty' \
          /tmp/retail-operation.json \
          2>/dev/null \
          || true
    )"


    if [[ "${HEALTH_CODE}" == "200" ]] \
       && [[ "${HEALTH_STATUS}" == "UP" ]] \
       && [[ "${STATUS_CODE}" == "200" ]] \
       && [[ "${FUNCTIONAL_STATUS}" == "READY" ]] \
       && [[ "${OP_CODE}" == "200" ]] \
       && [[ "${OP_STATUS}" == "SUCCESS" ]]
    then

        BUSINESS_READY=1

        ok "Business readiness" "READY after ${i}s"

        break

    fi

    sleep 1

done


rm -f \
  /tmp/retail-health.json \
  /tmp/retail-status.json \
  /tmp/retail-operation.json


if (( BUSINESS_READY == 0 ))
then
    fail "Business readiness" "TIMEOUT"
fi


# ------------------------------------------------------------
# OBSERVABILITY VALIDATION
# ------------------------------------------------------------

INSTANA_READY="$(
    ${K} \
      -n instana-agent \
      get daemonset instana-agent \
      -o jsonpath='{.status.numberReady}' \
      2>/dev/null \
      || true
)"

[[ "${INSTANA_READY}" == "1" ]] \
    || fail "Instana Agent" "${INSTANA_READY:-0}/1"

ok "Instana Agent" "1/1 READY"


K8_READY="$(
    ${K} \
      -n instana-agent \
      get deployment instana-agent-k8sensor \
      -o jsonpath='{.status.readyReplicas}' \
      2>/dev/null \
      || true
)"

[[ "${K8_READY}" == "1" ]] \
    || fail "Instana K8Sensor" "${K8_READY:-0}/1"

ok "Instana K8Sensor" "1/1 READY"


OTEL_READY="$(
    ${K} \
      -n instana-critical-demo \
      get daemonset otel-retail-logs \
      -o jsonpath='{.status.numberReady}' \
      2>/dev/null \
      || true
)"

[[ "${OTEL_READY}" == "1" ]] \
    || fail "OTel Retail" "${OTEL_READY:-0}/1"

ok "OTel Retail" "1/1 READY"


SYN_COUNT=0

for deployment in \
    synthetic-pop-controller \
    synthetic-pop-browserscript-playback-engine \
    synthetic-pop-http-playback-engine \
    synthetic-pop-ism-playback-engine \
    synthetic-pop-javascript-playback-engine \
    synthetic-pop-redis
do

    READY="$(
        ${K} \
          -n instana-synthetic \
          get deployment "${deployment}" \
          -o jsonpath='{.status.readyReplicas}' \
          2>/dev/null \
          || true
    )"

    if [[ "${READY}" == "1" ]]
    then
        SYN_COUNT=$((SYN_COUNT + 1))
    fi

done


[[ "${SYN_COUNT}" == "6" ]] \
    || fail "Synthetic PoP" "${SYN_COUNT}/6 READY"

ok "Synthetic PoP" "6/6 READY"


# ------------------------------------------------------------
# CHANGE SUMMARY
# ------------------------------------------------------------

echo
echo "========================================================"
echo " DEMO APPS CHANGE SUMMARY"
echo "========================================================"

printf '%-32s %s\n' "Source changed"          "${SOURCE_CHANGED}"
printf '%-32s %s\n' "Containerfile changed"   "${CONTAINER_CHANGED}"
printf '%-32s %s\n' "Retail manifest file"    "${RETAIL_FILE_CHANGED}"
printf '%-32s %s\n' "OTel manifest file"      "${OTEL_FILE_CHANGED}"
printf '%-32s %s\n' "Maven build"             "${MAVEN_BUILD}"
printf '%-32s %s\n' "Container image build"   "${IMAGE_BUILD}"
printf '%-32s %s\n' "Retail Kubernetes apply" "${RETAIL_K8S_APPLY}"
printf '%-32s %s\n' "Retail rollout"          "${RETAIL_ROLLOUT}"
printf '%-32s %s\n' "OTel Kubernetes apply"   "${OTEL_K8S_APPLY}"
printf '%-32s %s\n' "OTel rollout"            "${OTEL_ROLLOUT}"

echo
echo "========================================================"
echo " DEMO APPS APPLY = COMPLETE"
echo "========================================================"
echo

REMOTE_APPLY


# ------------------------------------------------------------
# FINAL CHECK
# ------------------------------------------------------------

echo
echo "========================================================"
echo " FINAL DEMO APPS CHECK"
echo "========================================================"
echo

"${CHECK_SCRIPT}" --check


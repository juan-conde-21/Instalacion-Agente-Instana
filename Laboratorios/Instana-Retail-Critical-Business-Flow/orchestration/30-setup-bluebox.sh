#!/usr/bin/env bash
set -uo pipefail

MODE="${1:---check}"

SSH_KEY="${SSH_KEY:-/home/admin/.ssh/id_rsa}"
BLUEBOX_HOST="${BLUEBOX_HOST:-192.168.252.35}"
BLUEBOX_USER="${BLUEBOX_USER:-jammer}"

case "${MODE}" in
    --check|--apply) ;;
    *)
        echo "Usage:"
        echo "  $0 --check"
        echo "  $0 --apply"
        exit 2
        ;;
esac

if [[ ! -f "${SSH_KEY}" ]]; then
    echo "[FAIL] SSH key missing: ${SSH_KEY}"
    exit 1
fi

ssh \
  -i "${SSH_KEY}" \
  -o BatchMode=yes \
  -o StrictHostKeyChecking=no \
  "${BLUEBOX_USER}@${BLUEBOX_HOST}" \
  "sudo -n env BLUEBOX_MODE='${MODE}' bash -s" <<'REMOTE'

set -uo pipefail

MODE="${BLUEBOX_MODE}"

FAILURES=0
WARNINGS=0

CHANGED_CENTRAL=0
CHANGED_CENTRAL_UNIT=0
CHANGED_OTEL=0
CHANGED_OTEL_UNIT=0
CHANGED_FILEMON=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

ok() {
    printf "${GREEN}[OK]   ${RESET} %-34s %s\n" "$1" "${2:-}"
}

fail() {
    printf "${RED}[FAIL] ${RESET} %-34s %s\n" "$1" "${2:-}"
    FAILURES=$((FAILURES + 1))
}

warn() {
    printf "${YELLOW}[WARN] ${RESET} %-34s %s\n" "$1" "${2:-}"
    WARNINGS=$((WARNINGS + 1))
}

info() {
    printf "${CYAN}[INFO] ${RESET} %-34s %s\n" "$1" "${2:-}"
}

install_if_changed() {
    local src="$1"
    local dst="$2"
    local owner="$3"
    local group="$4"
    local mode="$5"

    if [[ -f "${dst}" ]] && cmp -s "${src}" "${dst}"; then
        rm -f "${src}"
        return 1
    fi

    install \
      -o "${owner}" \
      -g "${group}" \
      -m "${mode}" \
      "${src}" \
      "${dst}"

    rm -f "${src}"
    return 0
}

check_service() {
    local unit="$1"
    local label="$2"

    if systemctl is-enabled "${unit}" >/dev/null 2>&1; then
        ok "${label}" "ENABLED"
    else
        fail "${label}" "NOT ENABLED"
    fi

    if systemctl is-active "${unit}" >/dev/null 2>&1; then
        ok "${label}" "ACTIVE"
    else
        fail "${label}" "NOT ACTIVE"
    fi
}

http_check() {
    local label="$1"
    local url="$2"

    local tmp
    local code

    tmp=$(mktemp)

    code=$(
        curl -sS \
          --connect-timeout 5 \
          --max-time 10 \
          -o "${tmp}" \
          -w '%{http_code}' \
          "${url}" \
          2>/dev/null || true
    )

    if [[ "${code}" == "200" ]]; then
        ok "${label}" "HTTP 200"
    else
        fail "${label}" "HTTP ${code:-UNREACHABLE}"
    fi

    rm -f "${tmp}"
}

wait_http_200() {

    local label="$1"
    local url="$2"
    local timeout="${3:-30}"

    local elapsed=0
    local code=""

    while (( elapsed < timeout )); do

        code=$(
            curl -sS               --connect-timeout 2               --max-time 3               -o /dev/null               -w '%{http_code}'               "${url}"               2>/dev/null || true
        )

        if [[ "${code}" == "200" ]]; then
            ok "${label}" "READY after ${elapsed}s"
            return 0
        fi

        sleep 1
        elapsed=$((elapsed + 1))
    done

    fail "${label}" "TIMEOUT after ${timeout}s / HTTP ${code:-000}"
    return 1
}

validate_all() {

    echo
    echo "Final validation"

    if [[ "$(hostname)" == "bluebox" ]]; then
        ok "Hostname" "bluebox"
    else
        fail "Hostname" "$(hostname)"
    fi

    if getent passwd instanademo >/dev/null 2>&1; then
        ok "User instanademo" "PRESENT"
    else
        fail "User instanademo" "MISSING"
    fi

    if [[ -f /opt/instana-demo/central/app/central-service.jar ]]; then
        local jar_size
        jar_size=$(stat -c%s /opt/instana-demo/central/app/central-service.jar)

        if (( jar_size > 20000000 )); then
            ok "CENTRAL JAR" "${jar_size} bytes"
        else
            fail "CENTRAL JAR" "${jar_size} bytes"
        fi
    else
        fail "CENTRAL JAR" "MISSING"
    fi

    check_service \
      instana-demo-central.service \
      "CENTRAL service"

    http_check \
      "CENTRAL health" \
      "http://127.0.0.1:18082/health"

    http_check \
      "CENTRAL file status" \
      "http://127.0.0.1:18082/api/files/status"

    http_check \
      "RETAIL downstream" \
      "http://192.168.252.33:18083/health"

    check_service \
      instana-agent.service \
      "Instana Agent"

    if ss -lntp 2>/dev/null | grep -q ':4317'; then
        ok "Instana OTLP gRPC" "4317 LISTENING"
    else
        fail "Instana OTLP gRPC" "NOT LISTENING"
    fi

    if ss -lntp 2>/dev/null | grep -q ':4318'; then
        ok "Instana OTLP HTTP" "4318 LISTENING"
    else
        fail "Instana OTLP HTTP" "NOT LISTENING"
    fi

    local fm
    fm="/opt/instana/agent/etc/instana/configuration-demo.yaml"

    if [[ -f "${fm}" ]] \
       && grep -q 'SIZE < 150000' "${fm}" \
       && grep -q 'LAST_MODIFIED_TIME > 0D:0H:2M' "${fm}"
    then
        ok "Instana File Monitoring" "CONFIGURED"
    else
        fail "Instana File Monitoring" "INVALID"
    fi

    if [[ -x /usr/local/bin/otelcol-contrib ]]; then
        ok "OTel Collector" "$(/usr/local/bin/otelcol-contrib --version 2>&1)"
    else
        fail "OTel Collector" "BINARY MISSING"
    fi

    check_service \
      otelcol-central.service \
      "OTel Collector service"

    if [[ -d /var/lib/otelcol-contrib-central ]]; then
        ok "OTel file storage" "PRESENT"
    else
        fail "OTel file storage" "MISSING"
    fi

    local pub
    pub="/opt/instana-demo/central/published/promotions_current.csv"

    if [[ -f "${pub}" ]]; then
        local size
        size=$(stat -c%s "${pub}")

        if (( size > 150000 )); then
            ok "Published CSV" "${size} bytes"
        else
            fail "Published CSV" "${size} bytes"
        fi
    else
        fail "Published CSV" "MISSING"
    fi

    for f in \
      /opt/instana-demo/scripts/fault-stale.sh \
      /opt/instana-demo/scripts/recover-stale.sh
    do
        if [[ -x "${f}" ]]; then
            ok "$(basename "${f}")" "EXECUTABLE"
        else
            fail "$(basename "${f}")" "INVALID"
        fi
    done
}


echo
echo "========================================================"
echo " INSTANA RETAIL LAB - BLUEBOX"
echo "========================================================"
echo

if [[ "${MODE}" == "--check" ]]; then

    info "Mode" "READ ONLY"
    validate_all

    echo
    echo "========================================================"

    if (( FAILURES == 0 )); then
        echo " BLUEBOX CHECK = READY"
    else
        echo " BLUEBOX CHECK = FAILED"
    fi

    echo "========================================================"
    echo
    echo "Failures : ${FAILURES}"
    echo "Warnings : ${WARNINGS}"
    echo

    exit "${FAILURES}"
fi


# ============================================================
# APPLY
# ============================================================

info "Mode" "APPLY"

if [[ ! -x /usr/local/bin/otelcol-contrib ]]; then
    fail "OTel prerequisite" "/usr/local/bin/otelcol-contrib missing"
fi

if [[ ! -d /opt/instana/agent ]]; then
    fail "Instana prerequisite" "/opt/instana/agent missing"
fi

if (( FAILURES > 0 )); then
    exit "${FAILURES}"
fi


# ============================================================
# ACCOUNT
# ============================================================

if ! getent group instanademo >/dev/null 2>&1; then
    groupadd --system instanademo
fi

if ! getent passwd instanademo >/dev/null 2>&1; then
    useradd \
      --system \
      --gid instanademo \
      --home-dir /opt/instana-demo \
      --shell /sbin/nologin \
      instanademo
fi

ok "Demo account" "instanademo:instanademo"


# ============================================================
# DIRECTORIES
# ============================================================

install -d -o instanademo -g instanademo -m 0755 \
  /opt/instana-demo \
  /opt/instana-demo/central \
  /opt/instana-demo/central/app \
  /opt/instana-demo/central/published \
  /opt/instana-demo/central/src \
  /opt/instana-demo/central/src/main \
  /opt/instana-demo/central/src/main/java \
  /opt/instana-demo/central/src/main/java/com \
  /opt/instana-demo/central/src/main/java/com/ibm \
  /opt/instana-demo/central/src/main/java/com/ibm/demo \
  /opt/instana-demo/central/src/main/java/com/ibm/demo/central \
  /opt/instana-demo/central/src/main/resources \
  /var/log/instana-demo

install -d -o root -g root -m 0755 \
  /opt/instana-demo/scripts \
  /etc/otelcol-contrib

install -d -o root -g root -m 0755 \
  /var/lib/otelcol-contrib-central

ok "Directories" "READY"


# ============================================================
# POM
# ============================================================

TMP=$(mktemp)

cat > "${TMP}" <<'POM'
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         https://maven.apache.org/xsd/maven-4.0.0.xsd">

  <modelVersion>4.0.0</modelVersion>

  <parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>3.5.16</version>
  </parent>

  <groupId>com.ibm.demo</groupId>
  <artifactId>central-service</artifactId>
  <version>1.0.0</version>

  <properties>
    <java.version>17</java.version>
  </properties>

  <dependencies>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-web</artifactId>
    </dependency>
  </dependencies>

  <build>
    <finalName>central-service</finalName>
    <plugins>
      <plugin>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-maven-plugin</artifactId>
      </plugin>
    </plugins>
  </build>
</project>
POM

if install_if_changed \
  "${TMP}" \
  /opt/instana-demo/central/pom.xml \
  instanademo instanademo 0644
then
    CHANGED_CENTRAL=1
    ok "CENTRAL pom.xml" "UPDATED"
else
    ok "CENTRAL pom.xml" "UNCHANGED"
fi


# ============================================================
# APPLICATION PROPERTIES
# ============================================================

TMP=$(mktemp)

cat > "${TMP}" <<'PROPS'
server.port=18082
spring.application.name=instana-demo-central
demo.app.url=http://192.168.252.33:18083

logging.file.name=/var/log/instana-demo/central-service.log
logging.level.root=INFO

server.error.include-message=always
PROPS

if install_if_changed \
  "${TMP}" \
  /opt/instana-demo/central/src/main/resources/application.properties \
  instanademo instanademo 0644
then
    CHANGED_CENTRAL=1
    ok "CENTRAL properties" "UPDATED"
else
    ok "CENTRAL properties" "UNCHANGED"
fi


# ============================================================
# JAVA SOURCE
# ============================================================

TMP=$(mktemp)

cat > "${TMP}" <<'JAVA'
package com.ibm.demo.central;

import java.io.IOException;
import java.nio.file.*;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.core.io.FileSystemResource;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.client.RestClient;

@SpringBootApplication
@RestController
public class CentralApplication {

    private static final Logger log =
        LoggerFactory.getLogger(CentralApplication.class);

    private static final Path DIR =
        Paths.get("/opt/instana-demo/central/published");

    private static final Path FILE =
        DIR.resolve("promotions_current.csv");

    private static final Path VERSION_FILE =
        DIR.resolve("promotions_current.version");

    private final RestClient restClient = RestClient.create();

    @Value("${demo.app.url:http://192.168.252.33:18083}")
    private String appUrl;

    public static void main(String[] args) {
        SpringApplication.run(CentralApplication.class, args);
    }

    @GetMapping("/health")
    public Map<String,Object> health() {
        return Map.of(
            "status", "UP",
            "service", "central-service",
            "timestamp", Instant.now().toString()
        );
    }

    @PostMapping(
        value="/api/files/upload",
        consumes=MediaType.ALL_VALUE
    )
    public ResponseEntity<Map<String,Object>> upload(
        @RequestBody byte[] body,
        @RequestHeader(value="X-Version", defaultValue="unknown") String version
    ) {

        Map<String,Object> response = new LinkedHashMap<>();

        try {
            Files.createDirectories(DIR);

            Path tmp = DIR.resolve("promotions_current.csv.tmp");

            Files.write(
                tmp,
                body,
                StandardOpenOption.CREATE,
                StandardOpenOption.TRUNCATE_EXISTING
            );

            Files.move(
                tmp,
                FILE,
                StandardCopyOption.REPLACE_EXISTING,
                StandardCopyOption.ATOMIC_MOVE
            );

            Files.writeString(
                VERSION_FILE,
                version,
                StandardOpenOption.CREATE,
                StandardOpenOption.TRUNCATE_EXISTING
            );

            long size = Files.size(FILE);

            log.info(
                "event=file_published version={} size_bytes={} path={}",
                version,
                size,
                FILE
            );

            boolean syncSuccess = false;
            String syncError = null;

            try {
                restClient
                    .post()
                    .uri(appUrl + "/api/sync?version={version}", version)
                    .retrieve()
                    .toBodilessEntity();

                syncSuccess = true;

                log.info(
                    "event=downstream_sync_triggered version={} target={}",
                    version,
                    appUrl
                );

            } catch (Exception ex) {

                syncError = ex.getMessage();

                log.error(
                    "event=downstream_sync_failed version={} target={} error={}",
                    version,
                    appUrl,
                    ex.toString()
                );
            }

            response.put("status", "PUBLISHED");
            response.put("version", version);
            response.put("sizeBytes", size);
            response.put("syncTriggered", syncSuccess);

            if (syncError != null)
                response.put("syncError", syncError);

            return ResponseEntity.ok(response);

        } catch (Exception ex) {

            log.error(
                "event=file_publish_failed version={} error={}",
                version,
                ex.toString()
            );

            response.put("status", "ERROR");
            response.put("version", version);
            response.put("error", ex.getMessage());

            return ResponseEntity
                .status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(response);
        }
    }

    @GetMapping("/api/files/status")
    public Map<String,Object> status() throws IOException {

        Map<String,Object> result = new LinkedHashMap<>();

        boolean exists = Files.exists(FILE);

        result.put("exists", exists);
        result.put("path", FILE.toString());

        if (exists) {
            result.put("sizeBytes", Files.size(FILE));

            Instant modified =
                Files.getLastModifiedTime(FILE).toInstant();

            result.put(
                "lastModified",
                modified.toString()
            );

            result.put(
                "ageSeconds",
                Instant.now().getEpochSecond()
                - modified.getEpochSecond()
            );
        }

        if (Files.exists(VERSION_FILE)) {
            result.put(
                "version",
                Files.readString(VERSION_FILE).trim()
            );
        }

        return result;
    }

    @GetMapping("/downloads/promotions_current.csv")
    public ResponseEntity<FileSystemResource> download() {

        if (!Files.exists(FILE))
            return ResponseEntity.notFound().build();

        FileSystemResource resource =
            new FileSystemResource(FILE);

        return ResponseEntity.ok()
            .contentType(MediaType.valueOf("text/csv"))
            .header(
                HttpHeaders.CONTENT_DISPOSITION,
                "inline; filename=promotions_current.csv"
            )
            .body(resource);
    }
}
JAVA

if install_if_changed \
  "${TMP}" \
  /opt/instana-demo/central/src/main/java/com/ibm/demo/central/CentralApplication.java \
  instanademo instanademo 0644
then
    CHANGED_CENTRAL=1
    ok "CENTRAL Java source" "UPDATED"
else
    ok "CENTRAL Java source" "UNCHANGED"
fi


# ============================================================
# CENTRAL BUILD
# ============================================================

if [[ ! -f /opt/instana-demo/central/app/central-service.jar ]]; then
    CHANGED_CENTRAL=1
fi

if (( CHANGED_CENTRAL == 1 )); then

    info "CENTRAL build" "RUNNING"

    if sudo -u instanademo \
       mvn \
       -q \
       -f /opt/instana-demo/central/pom.xml \
       clean package \
       -DskipTests
    then

        install \
          -o instanademo \
          -g instanademo \
          -m 0644 \
          /opt/instana-demo/central/target/central-service.jar \
          /opt/instana-demo/central/app/central-service.jar

        ok "CENTRAL build" "COMPLETE"

    else
        fail "CENTRAL build" "FAILED"
    fi

else
    ok "CENTRAL build" "NOT REQUIRED"
fi


# ============================================================
# CENTRAL SYSTEMD
# ============================================================

TMP=$(mktemp)

cat > "${TMP}" <<'UNIT'
[Unit]
Description=Instana Demo Central Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=instanademo
Group=instanademo

Environment="JAVA_OPTS=-Xms64m -Xmx192m"

ExecStart=/usr/bin/java -Xms64m -Xmx192m -jar /opt/instana-demo/central/app/central-service.jar

Restart=on-failure
RestartSec=5
SuccessExitStatus=143

[Install]
WantedBy=multi-user.target
UNIT

if install_if_changed \
  "${TMP}" \
  /etc/systemd/system/instana-demo-central.service \
  root root 0644
then
    CHANGED_CENTRAL_UNIT=1
    ok "CENTRAL systemd" "UPDATED"
else
    ok "CENTRAL systemd" "UNCHANGED"
fi


# ============================================================
# FILE MONITORING
# ============================================================

TMP=$(mktemp)

cat > "${TMP}" <<'FM'
com.instana.plugin.filemonitoring:
  enabled: true

  file_events:

    - event_intervals:
        - interval_1: 30

    - path: '/opt/instana-demo/central/published/promotions_current.csv'
      conditions:
        - 'SIZE < 150000'
      name: 'demo-promotions-size-too-small'
      interval: 'interval_1'
      severity: 'CRITICAL'

    - path: '/opt/instana-demo/central/published/promotions_current.csv'
      conditions:
        - 'LAST_MODIFIED_TIME > 0D:0H:2M'
      name: 'demo-promotions-file-stale'
      interval: 'interval_1'
      severity: 'CRITICAL'
FM

if install_if_changed \
  "${TMP}" \
  /opt/instana/agent/etc/instana/configuration-demo.yaml \
  root root 0640
then
    CHANGED_FILEMON=1
    ok "File Monitoring config" "UPDATED"
else
    ok "File Monitoring config" "UNCHANGED"
fi


# ============================================================
# OTEL CONFIG
# ============================================================

TMP=$(mktemp)

cat > "${TMP}" <<'OTEL'
extensions:

  file_storage:
    directory: /var/lib/otelcol-contrib-central


receivers:

  filelog/central:

    include:
      - /var/log/instana-demo/central-service.log

    start_at: beginning

    include_file_path: true
    include_file_name: true

    storage: file_storage

    retry_on_failure:
      enabled: true

    operators:

      - type: recombine
        combine_field: body
        is_first_entry: 'body matches "^[0-9]{4}-[0-9]{2}-[0-9]{2}T"'
        source_identifier: attributes["log.file.path"]


processors:

  resource/central:

    attributes:

      - key: service.name
        value: central-service
        action: upsert

      - key: service.instance.id
        value: bluebox-central
        action: upsert

      - key: host.name
        value: bluebox
        action: upsert

      - key: demo.component
        value: central
        action: upsert


  transform/severity:

    log_statements:

      - context: log
        statements:

          - set(severity_text, "INFO")
            where IsMatch(body.string, ".* INFO .*")

          - set(severity_text, "WARN")
            where IsMatch(body.string, ".* WARN .*")

          - set(severity_text, "ERROR")
            where IsMatch(body.string, ".* ERROR .*")


  batch: {}


exporters:

  otlp/instana:

    endpoint: 127.0.0.1:4317

    tls:
      insecure: true


service:

  telemetry:
    metrics:
      readers:
        - pull:
            exporter:
              prometheus:
                host: '127.0.0.1'
                port: 18888

  extensions:
    - file_storage

  pipelines:

    logs:

      receivers:
        - filelog/central

      processors:
        - resource/central
        - transform/severity
        - batch

      exporters:
        - otlp/instana
OTEL

if install_if_changed \
  "${TMP}" \
  /etc/otelcol-contrib/central.yaml \
  root root 0644
then
    CHANGED_OTEL=1
    ok "OTel config" "UPDATED"
else
    ok "OTel config" "UNCHANGED"
fi


# ============================================================
# OTEL SYSTEMD
# ============================================================

TMP=$(mktemp)

cat > "${TMP}" <<'UNIT'
[Unit]
Description=OTel Collector - Instana Demo Central Logs
After=network-online.target instana-agent.service
Wants=network-online.target

[Service]
Type=simple

ExecStart=/usr/local/bin/otelcol-contrib --config=/etc/otelcol-contrib/central.yaml

Restart=always
RestartSec=5

LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
UNIT

if install_if_changed \
  "${TMP}" \
  /etc/systemd/system/otelcol-central.service \
  root root 0644
then
    CHANGED_OTEL_UNIT=1
    ok "OTel systemd" "UPDATED"
else
    ok "OTel systemd" "UNCHANGED"
fi


# ============================================================
# FAILURE SCRIPT
# ============================================================

TMP=$(mktemp)

cat > "${TMP}" <<'FAULT'
#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: ejecutar con sudo"
  exit 1
fi

DIR="/opt/instana-demo/central/published"
FILE="${DIR}/promotions_current.csv"

echo
echo "=============================================="
echo " INYECTANDO FALLA: DISTRIBUCION BLOQUEADA"
echo "=============================================="

stat -c 'file=%n size=%s modified=%y' "${FILE}"

CURRENT_MODE="$(stat -c '%a' "${DIR}")"

echo "${CURRENT_MODE}" \
  > /opt/instana-demo/central/.published-mode-before-fault

chmod 0555 "${DIR}"

stat -c '%A %a %U:%G %n' "${DIR}"

systemctl is-active instana-demo-central

curl -fsS http://127.0.0.1:18082/health
echo

echo
echo "=============================================="
echo " FALLA ACTIVADA"
echo "=============================================="
echo
echo "SOURCE continuará generando archivos."
echo "CENTRAL ya no podrá publicar nuevas versiones."
echo "Esperar aproximadamente 2-3 minutos."
FAULT

if install_if_changed \
  "${TMP}" \
  /opt/instana-demo/scripts/fault-stale.sh \
  root root 0755
then
    ok "fault-stale.sh" "UPDATED"
else
    ok "fault-stale.sh" "UNCHANGED"
fi


# ============================================================
# RECOVERY SCRIPT
# ============================================================

TMP=$(mktemp)

cat > "${TMP}" <<'RECOVER'
#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: ejecutar con sudo"
  exit 1
fi

DIR="/opt/instana-demo/central/published"
MODE_FILE="/opt/instana-demo/central/.published-mode-before-fault"

echo
echo "=============================================="
echo " RECUPERANDO DISTRIBUCION"
echo "=============================================="

if [[ -f "${MODE_FILE}" ]]; then
  ORIGINAL_MODE="$(cat "${MODE_FILE}")"
else
  ORIGINAL_MODE="755"
fi

chmod "${ORIGINAL_MODE}" "${DIR}"

chown \
  instanademo:instanademo \
  "${DIR}"

stat -c '%A %a %U:%G %n' "${DIR}"

curl -fsS http://127.0.0.1:18082/health
echo

echo
echo "=============================================="
echo " DISTRIBUCION HABILITADA"
echo "=============================================="
echo
echo "El siguiente job de SOURCE actualizará Central."
RECOVER

if install_if_changed \
  "${TMP}" \
  /opt/instana-demo/scripts/recover-stale.sh \
  root root 0755
then
    ok "recover-stale.sh" "UPDATED"
else
    ok "recover-stale.sh" "UNCHANGED"
fi


# ============================================================
# SYSTEMD ACTIVATION
# ============================================================

if (( CHANGED_CENTRAL_UNIT == 1 || CHANGED_OTEL_UNIT == 1 )); then
    systemctl daemon-reload
    ok "systemd daemon-reload" "EXECUTED"
else
    ok "systemd daemon-reload" "NOT REQUIRED"
fi

systemctl enable instana-demo-central.service >/dev/null
systemctl enable otelcol-central.service >/dev/null
systemctl enable instana-agent.service >/dev/null


if (( CHANGED_FILEMON == 1 )); then
    info "Instana Agent" "RESTARTING - config changed"
    systemctl restart instana-agent.service
else
    ok "Instana Agent restart" "NOT REQUIRED"
fi


if (( CHANGED_CENTRAL == 1 || CHANGED_CENTRAL_UNIT == 1 )); then
    info "CENTRAL service" "RESTARTING"
    systemctl restart instana-demo-central.service
else
    ok "CENTRAL restart" "NOT REQUIRED"
fi


if (( CHANGED_OTEL == 1 || CHANGED_OTEL_UNIT == 1 || CHANGED_FILEMON == 1 )); then
    info "OTel Collector" "RESTARTING"
    systemctl restart otelcol-central.service
else
    ok "OTel restart" "NOT REQUIRED"
fi


# ============================================================
# WAIT FOR SERVICES
# ============================================================

if (( CHANGED_CENTRAL == 1 || CHANGED_CENTRAL_UNIT == 1 )); then

    wait_http_200       "CENTRAL startup"       "http://127.0.0.1:18082/health"       30

else
    ok "CENTRAL startup wait" "NOT REQUIRED"
fi


# ============================================================
# FINAL
# ============================================================

validate_all

echo
echo "Change summary"
echo "  CENTRAL source/build : ${CHANGED_CENTRAL}"
echo "  CENTRAL systemd      : ${CHANGED_CENTRAL_UNIT}"
echo "  File Monitoring      : ${CHANGED_FILEMON}"
echo "  OTel config           : ${CHANGED_OTEL}"
echo "  OTel systemd          : ${CHANGED_OTEL_UNIT}"

echo
echo "========================================================"

if (( FAILURES == 0 )); then
    echo " BLUEBOX SETUP = COMPLETE"
else
    echo " BLUEBOX SETUP = FAILED"
fi

echo "========================================================"
echo
echo "Failures : ${FAILURES}"
echo "Warnings : ${WARNINGS}"
echo

exit "${FAILURES}"
REMOTE

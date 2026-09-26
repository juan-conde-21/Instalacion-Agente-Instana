# Instalación de Instana Distribution of OpenTelemetry Collector (IDOT) en Linux

## 1. Objetivo

Esta guía describe la instalación y configuración de **Instana Distribution of OpenTelemetry Collector (IDOT)** en servidores Linux utilizando el instalador oficial publicado en GitHub.

El procedimiento fue validado en **Red Hat Enterprise Linux 9** y utiliza el servicio `systemd` creado por el instalador.

En esta guía se cubre:

- Descarga de la última versión disponible.
- Instalación automática de IDOT.
- Validación del servicio.
- Configuración de `config.env`.
- Identificación del host en Instana.
- Asignación de una zona mediante `host.zone`.
- Configuración de los processors y pipelines.
- Ingesta de logs desde archivos locales.
- Reinicio y validación del collector.
- Comandos equivalentes para las distribuciones Linux más utilizadas.

> **Importante:** IDOT puede trabajar sin tener instalado el Instana Host Agent. En este procedimiento el collector envía la información directamente al backend SaaS de Instana.

---

## 2. Arquitectura

### Escenario principal

```text
Linux Server
     |
     |-- Métricas del sistema
     |-- Procesos
     |-- Logs de aplicaciones
     |-- Telemetría OTLP
     |
     v
Instana IDOT Collector
     |
     | OTLP/HTTP - HTTPS/443
     v
Instana SaaS
```

El Instana Host Agent no es obligatorio para este escenario.

---

## 3. Compatibilidad y arquitectura

El repositorio oficial de IDOT publica instaladores Linux para:

```text
x86-64 / amd64
s390x / IBM Z
```

Validar la arquitectura del servidor:

```bash
uname -m
```

Resultados comunes:

```text
x86_64  -> utilizar linux-amd64
s390x   -> utilizar linux-s390x
```

Esta guía utiliza `linux-amd64`.

> El procedimiento asume una distribución Linux con `systemd`, que es el esquema utilizado por el instalador para registrar y administrar el servicio.

---

## 4. Preparar el servidor

Validar que `curl` esté disponible:

```bash
curl --version
```

Si no está instalado, utilizar el comando correspondiente a la distribución.

### Red Hat Enterprise Linux / Rocky Linux / AlmaLinux / Oracle Linux

```bash
sudo dnf install -y curl
```

En versiones que todavía utilicen `yum`:

```bash
sudo yum install -y curl
```

### Ubuntu / Debian

```bash
sudo apt update
sudo apt install -y curl
```

### SUSE Linux Enterprise Server / openSUSE

```bash
sudo zypper install -y curl
```

Si la sesión ya está ejecutándose como `root`, se puede omitir `sudo` en los comandos de esta guía.

---

## 5. Descargar la última versión de IDOT

Para Linux x86-64 / amd64 utilizar el instalador `latest` publicado por Instana:

```bash
cd /opt

curl -Lo instana_otelcol_setup.sh \
https://github.com/instana/instana-otel-collector/releases/latest/download/instana-otel-collector-installer-latest-linux-amd64.sh
```

Asignar permisos de ejecución:

```bash
chmod +x instana_otelcol_setup.sh
```

Validar:

```bash
ls -lh instana_otelcol_setup.sh
```

### IBM Z / s390x

Para servidores `s390x`, utilizar:

```bash
curl -Lo instana_otelcol_setup.sh \
https://github.com/instana/instana-otel-collector/releases/latest/download/instana-otel-collector-installer-latest-linux-s390x.sh
```

> Para el manual se utiliza el nombre de asset documentado actualmente por el repositorio oficial. El uso de `latest` evita amarrar el procedimiento a una versión específica.

---

## 6. Ejecutar la instalación

Se requieren los siguientes valores del tenant de Instana:

```text
Agent Key
OTLP gRPC Endpoint
OTLP HTTP Endpoint
```

Ejemplo para la región `coral`:

```text
gRPC : otlp-grpc-coral-saas.instana.io:443
HTTP : otlp-http-coral-saas.instana.io:443
```

Ejecutar:

```bash
sudo ./instana_otelcol_setup.sh \
  -a "<INSTANA_AGENT_KEY>" \
  -e "otlp-grpc-coral-saas.instana.io:443" \
  -H "otlp-http-coral-saas.instana.io:443"
```

Si se está trabajando directamente como `root`:

```bash
./instana_otelcol_setup.sh \
  -a "<INSTANA_AGENT_KEY>" \
  -e "otlp-grpc-coral-saas.instana.io:443" \
  -H "otlp-http-coral-saas.instana.io:443"
```

### Parámetros utilizados

| Parámetro | Uso |
|---|---|
| `-a` | Agent Key del tenant de Instana. |
| `-e` | Endpoint OTLP gRPC. |
| `-H` | Endpoint OTLP HTTP. |
| `-u` | Controla el uso del Supervisor. El valor por defecto es `true`. |
| Ruta final | Si no se especifica otra ruta, la instalación se realiza bajo `/opt/instana`. |

El instalador realiza automáticamente las siguientes acciones:

- Extrae IDOT en `/opt/instana`.
- Genera `config.env`.
- Genera `config.yaml` a partir de la configuración base.
- Instala el servicio `systemd`.
- Habilita el servicio para iniciar con el sistema.
- Inicia el Supervisor y el proceso `instana-otelcol`.

Una instalación correcta debe finalizar con un estado similar a:

```text
Active: active (running)

CGroup: /system.slice/instana-collector.service
├─ supervisor
└─ instana-otelcol --config ../config/config.yaml
```

---

## 7. Estructura de instalación

La ubicación por defecto es:

```text
/opt/instana/collector
```

Validar:

```bash
ls -l /opt/instana/collector
```

Los principales directorios son:

```text
/opt/instana/collector/
├── bin/
├── config/
└── ...
```

Dentro de `bin`:

```bash
ls -l /opt/instana/collector/bin
```

Se encontrarán archivos similares a:

```text
instana_collector_service.sh
instana-otelcol
instana_supervisor_service.sh
supervisor
uninstall.sh
```

Los archivos de configuración se encuentran en:

```text
/opt/instana/collector/config/config.env
/opt/instana/collector/config/config.yaml
```

---

## 8. Validar el servicio

El instalador habilita el Supervisor de forma predeterminada.

Validar su estado:

```bash
cd /opt/instana/collector/bin

./instana_supervisor_service.sh status
```

También se puede validar directamente con `systemd`:

```bash
systemctl status instana-collector --no-pager -l
```

Un estado correcto debe mostrar:

```text
Active: active (running)
```

y mensajes similares a:

```text
Health check: healthy
```

---

## 9. Detener el servicio antes de modificar la configuración

Como el Supervisor está habilitado por defecto, detenerlo antes de realizar cambios:

```bash
cd /opt/instana/collector/bin

./instana_supervisor_service.sh stop
```

Validar:

```bash
./instana_supervisor_service.sh status
```

> Si IDOT fue instalado expresamente con `-u false`, administrar el collector con `instana_collector_service.sh` en lugar del Supervisor.

---

# 10. Configurar `config.env`

En Linux **no es necesario crear `config.env` manualmente**. El instalador lo genera durante la instalación.

Editar:

```bash
vi /opt/instana/collector/config/config.env
```

También se puede utilizar:

```bash
nano /opt/instana/collector/config/config.env
```

Mantener las variables generadas por el instalador y agregar al final:

```properties
# =========================================
# IDENTIFICACION DEL HOST EN INSTANA
# =========================================

INSTANA_OTEL_SERVICE_NAME=IDOT-Linux
INSTANA_ZONE=Produccion-Lima
```

### `INSTANA_OTEL_SERVICE_NAME`

Define un nombre legible para el collector.

Ejemplo:

```properties
INSTANA_OTEL_SERVICE_NAME=IDOT-Linux
```

Con un hostname como:

```text
podman-server
```

la entidad puede mostrarse en Instana de forma similar a:

```text
podman-server@IDOT-Linux
```

### `INSTANA_ZONE`

Esta variable es utilizada por nuestra plantilla para asignar el atributo OpenTelemetry:

```text
host.zone
```

Ejemplo:

```properties
INSTANA_ZONE=Produccion-Lima
```

El nombre puede adaptarse a la organización:

```properties
INSTANA_ZONE=Produccion-Lima
```

```properties
INSTANA_ZONE=QA-Lima
```

```properties
INSTANA_ZONE=Datacenter-Principal
```

> `INSTANA_ZONE` es una variable utilizada por esta configuración. El atributo que interpreta Instana para el host es `host.zone`.

---

# 11. Configurar `config.yaml`

El archivo se encuentra en:

```text
/opt/instana/collector/config/config.yaml
```

Antes de modificarlo, crear una copia:

```bash
cp /opt/instana/collector/config/config.yaml \
   /opt/instana/collector/config/config.yaml.bak
```

Editar:

```bash
vi /opt/instana/collector/config/config.yaml
```

No se recomienda trabajar con números de línea porque pueden cambiar entre versiones. Las modificaciones deben realizarse buscando los bloques indicados en esta guía.

---

## 12. Agregar la zona al processor del host

Buscar:

```yaml
processors:
```

y dentro de esa sección ubicar:

```yaml
resource/host:
```

Agregar `host.zone`.

El bloque debe quedar de forma similar a:

```yaml
  resource/host:
    attributes:
      - key: service.name
        value: ${env:INSTANA_OTEL_SERVICE_NAME:-otel-collector}
        action: upsert

      - key: host.name
        value: ${env:HOSTNAME:-hostname}
        action: upsert

      - key: host.zone
        value: ${env:INSTANA_ZONE:-Undefined}
        action: upsert
```

Esto permite agregar a la telemetría recolectada directamente desde el servidor:

```text
service.name
host.name
host.zone
```

---

## 13. Crear un processor para la zona OTLP

Dentro de la misma sección `processors`, agregar:

```yaml
  resource/zone:
    attributes:
      - key: host.zone
        value: ${env:INSTANA_ZONE}
        action: upsert
```

Ejemplo:

```yaml
processors:

  batch: {}

  resource/host:
    attributes:
      - key: service.name
        value: ${env:INSTANA_OTEL_SERVICE_NAME:-otel-collector}
        action: upsert

      - key: host.name
        value: ${env:HOSTNAME:-hostname}
        action: upsert

      - key: host.zone
        value: ${env:INSTANA_ZONE:-Undefined}
        action: upsert

  resource/zone:
    attributes:
      - key: host.zone
        value: ${env:INSTANA_ZONE}
        action: upsert
```

Separamos `resource/zone` de `resource/host` para no reemplazar el `service.name` de aplicaciones que posteriormente envíen su propia telemetría OTLP al collector.

---

# 14. Aplicar la zona en `service > pipelines`

Buscar:

```yaml
service:
  pipelines:
```

La regla es sencilla:

- Para telemetría OTLP, agregar `resource/zone`.
- Para métricas y logs recolectados directamente desde el host, utilizar `resource/host`.
- No eliminar los processors que ya existan en el archivo. Solo agregar el processor correspondiente.

### Traces OTLP

Ejemplo:

```yaml
    traces/otlp:
      receivers: [otlp/receiver]
      processors: [resource/zone, batch]
      exporters: [otlphttp/exporter]
```

### Logs OTLP

Si el pipeline ya utiliza `transform/severity_parse`, mantenerlo:

```yaml
    logs/otlp:
      receivers: [otlp/receiver]
      processors: [transform/severity_parse, resource/zone, batch]
      exporters: [otlphttp/exporter]
```

### Métricas OTLP

```yaml
    metrics/otlp:
      receivers: [otlp/receiver]
      processors: [resource/zone, batch]
      exporters: [otlphttp/exporter]
```

### Logs recolectados desde el servidor

```yaml
    logs/collector:
      receivers: [filelog]
      processors: [resource/host, transform/severity_parse, batch]
      exporters: [otlphttp/exporter]
```

Si la configuración generada contiene receivers adicionales para logs del sistema, mantenerlos en la lista.

### Métricas del servidor

```yaml
    metrics/collector:
      receivers: [hostmetrics]
      processors: [resource/host, batch]
      exporters: [otlphttp/exporter]
```

`resource/host` ya contiene `host.zone`, por lo que no es necesario agregar también `resource/zone` en `logs/collector` o `metrics/collector`.

---

# 15. Configurar los archivos de logs que serán ingeridos

La ruta de los logs se configura en:

```yaml
receivers:
  filelog:
```

Buscar el bloque `filelog` en `config.yaml`.

## Una ruta

Ejemplo:

```yaml
  filelog:
    include:
      - '/opt/aplicacion/logs/*.log'
    include_file_path: true
```

## Varias rutas

```yaml
  filelog:
    include:
      - '/opt/aplicacion1/logs/*.log'
      - '/opt/aplicacion2/logs/*.log'
      - '/var/log/middleware/*.log'
    include_file_path: true
```

## Incluir subdirectorios

```yaml
  filelog:
    include:
      - '/opt/aplicacion/logs/**/*.log'
    include_file_path: true
```

La diferencia es:

```text
*.log
```

Lee los archivos directamente en la ruta indicada.

Mientras:

```text
**/*.log
```

permite incluir subdirectorios.

### Ejemplos comunes en Linux

```yaml
  filelog:
    include:
      - '/var/log/myapp/*.log'
      - '/opt/weblogic/logs/*.log'
      - '/opt/tomcat/logs/*.log'
      - '/srv/application/logs/**/*.log'
    include_file_path: true
```

Antes de reiniciar, validar que las rutas existan:

```bash
ls -l /var/log/myapp/
```

o:

```bash
ls -l /opt/weblogic/logs/
```

> En la instalación validada en Red Hat Enterprise Linux 9, el servicio fue creado con `User=root`. Si se cambia el usuario del servicio, se deben validar permisos de lectura sobre todas las rutas configuradas.

---

## 16. Validar permisos de logs

Validar permisos:

```bash
ls -ld /ruta/de/logs
ls -l /ruta/de/logs/
```

Si el archivo existe pero no se ingiere, revisar también SELinux en distribuciones Red Hat compatibles:

```bash
getenforce
```

Si está en:

```text
Enforcing
```

y existen errores de acceso, revisar los eventos de auditoría antes de cambiar permisos o políticas.

---

# 17. Reiniciar IDOT

Después de modificar `config.env` y `config.yaml`, iniciar nuevamente el Supervisor:

```bash
cd /opt/instana/collector/bin

./instana_supervisor_service.sh start
```

Si el servicio ya se encuentra iniciado y solo se realizaron cambios de configuración:

```bash
./instana_supervisor_service.sh restart
```

Validar:

```bash
./instana_supervisor_service.sh status
```

También puede utilizarse:

```bash
systemctl status instana-collector --no-pager -l
```

El estado esperado es:

```text
Active: active (running)
```

y en los logs deben aparecer mensajes similares a:

```text
Health check: healthy
```

---

## 18. Esperar la actualización en Instana

Después del reinicio, dar unos minutos para que el collector vuelva a enviar telemetría y la entidad se actualice en Instana.

Como referencia práctica:

```text
Esperar aproximadamente 5 minutos.
```

Luego validar nuevamente la entidad y la zona en Instana.

---

# 19. Validar en Instana

En **Infrastructure Map**, el host debe aparecer dentro de la zona configurada.

Ejemplo:

```text
Produccion-Lima
└── OTelHost
    └── podman-server@IDOT-Linux
```

Validar principalmente los siguientes atributos:

```text
host.name
podman-server

host.zone
Produccion-Lima

service.name
IDOT-Linux
```

Si `host.zone` no llega en la telemetría, la entidad puede aparecer bajo:

```text
Undefined Zone
```

Para servidores on-premises esta guía utiliza:

```text
host.zone
```

La zona puede buscarse también con:

```text
entity.zone:"Produccion-Lima"
```

---

# 20. Revisar logs del servicio

Para revisar los últimos eventos del servicio:

```bash
journalctl -u instana-collector -n 100 --no-pager
```

Para seguirlos en tiempo real:

```bash
journalctl -u instana-collector -f
```

Para ver líneas completas:

```bash
journalctl -u instana-collector -l --no-pager
```

Mensajes como:

```text
Health check: healthy
```

confirman que el Supervisor está validando correctamente el proceso del collector.

Si aparece un mensaje relacionado con una configuración remota OpAMP y no se está utilizando configuración remota, primero validar que también aparezcan:

```text
Loaded effective config from file
Agent process started
Health check: healthy
```

Si el collector permanece `healthy`, continuar validando la configuración local antes de tratar el mensaje de OpAMP como una falla del servicio.

---

# 21. Administración del servicio

Con Supervisor habilitado:

```bash
cd /opt/instana/collector/bin
```

Estado:

```bash
./instana_supervisor_service.sh status
```

Detener:

```bash
./instana_supervisor_service.sh stop
```

Iniciar:

```bash
./instana_supervisor_service.sh start
```

Reiniciar:

```bash
./instana_supervisor_service.sh restart
```

También se puede revisar el unit de `systemd`:

```bash
systemctl status instana-collector
```

> Si IDOT fue instalado con `-u false`, utilizar `instana_collector_service.sh` para administrar directamente el collector.

---

# 22. Ejemplos por distribución

El instalador de IDOT es el mismo para Linux x86-64. Lo que normalmente cambia entre distribuciones es la instalación de dependencias y el uso de privilegios.

### Red Hat Enterprise Linux 8/9

```bash
sudo dnf install -y curl

cd /opt

sudo curl -Lo instana_otelcol_setup.sh \
https://github.com/instana/instana-otel-collector/releases/latest/download/instana-otel-collector-installer-latest-linux-amd64.sh

sudo chmod +x instana_otelcol_setup.sh

sudo ./instana_otelcol_setup.sh \
  -a "<INSTANA_AGENT_KEY>" \
  -e "otlp-grpc-coral-saas.instana.io:443" \
  -H "otlp-http-coral-saas.instana.io:443"
```

### Rocky Linux / AlmaLinux / Oracle Linux

```bash
sudo dnf install -y curl

cd /opt

sudo curl -Lo instana_otelcol_setup.sh \
https://github.com/instana/instana-otel-collector/releases/latest/download/instana-otel-collector-installer-latest-linux-amd64.sh

sudo chmod +x instana_otelcol_setup.sh

sudo ./instana_otelcol_setup.sh \
  -a "<INSTANA_AGENT_KEY>" \
  -e "otlp-grpc-coral-saas.instana.io:443" \
  -H "otlp-http-coral-saas.instana.io:443"
```

### Ubuntu Server

```bash
sudo apt update
sudo apt install -y curl

cd /opt

sudo curl -Lo instana_otelcol_setup.sh \
https://github.com/instana/instana-otel-collector/releases/latest/download/instana-otel-collector-installer-latest-linux-amd64.sh

sudo chmod +x instana_otelcol_setup.sh

sudo ./instana_otelcol_setup.sh \
  -a "<INSTANA_AGENT_KEY>" \
  -e "otlp-grpc-coral-saas.instana.io:443" \
  -H "otlp-http-coral-saas.instana.io:443"
```

### Debian

```bash
sudo apt update
sudo apt install -y curl

cd /opt

sudo curl -Lo instana_otelcol_setup.sh \
https://github.com/instana/instana-otel-collector/releases/latest/download/instana-otel-collector-installer-latest-linux-amd64.sh

sudo chmod +x instana_otelcol_setup.sh

sudo ./instana_otelcol_setup.sh \
  -a "<INSTANA_AGENT_KEY>" \
  -e "otlp-grpc-coral-saas.instana.io:443" \
  -H "otlp-http-coral-saas.instana.io:443"
```

### SUSE Linux Enterprise Server

```bash
sudo zypper install -y curl

cd /opt

sudo curl -Lo instana_otelcol_setup.sh \
https://github.com/instana/instana-otel-collector/releases/latest/download/instana-otel-collector-installer-latest-linux-amd64.sh

sudo chmod +x instana_otelcol_setup.sh

sudo ./instana_otelcol_setup.sh \
  -a "<INSTANA_AGENT_KEY>" \
  -e "otlp-grpc-coral-saas.instana.io:443" \
  -H "otlp-http-coral-saas.instana.io:443"
```

Para IBM Z / s390x cambiar únicamente el instalador por:

```text
instana-otel-collector-installer-latest-linux-s390x.sh
```

---

# 23. IDOT con o sin Instana Host Agent

## Sin Instana Host Agent

Es el escenario utilizado en esta guía:

```text
IDOT
  |
  | HTTPS/443
  v
Instana Backend
```

IDOT puede operar de manera independiente y enviar la telemetría directamente a Instana.

## Con Instana Host Agent

Si el servidor ya tiene un Instana Host Agent con recepción OTLP habilitada, también es posible utilizar el agente como destino local:

```text
IDOT
  |
  | OTLP
  v
Instana Host Agent
  |
  v
Instana Backend
```

Los puertos OTLP estándar utilizados por el agente son:

```text
4317 - OTLP/gRPC
4318 - OTLP/HTTP
```

Este escenario es opcional. Para una instalación de IDOT independiente no es necesario desplegar el Host Agent.

---

# 24. Desinstalar IDOT

El instalador deja un script de desinstalación en:

```text
/opt/instana/collector/bin/uninstall.sh
```

Ejecutar:

```bash
cd /opt/instana/collector/bin

sudo ./uninstall.sh
```

Si la sesión ya está como `root`:

```bash
./uninstall.sh
```

---

# 25. Troubleshooting rápido

## Validar servicio

```bash
systemctl status instana-collector --no-pager -l
```

## Validar logs

```bash
journalctl -u instana-collector -n 100 --no-pager
```

## Validar arquitectura

```bash
uname -m
```

## Validar acceso a los endpoints

```bash
curl -I https://otlp-http-coral-saas.instana.io:443
```

> Una respuesta HTTP específica del endpoint no es necesaria para validar la aplicación. Esta prueba se utiliza principalmente para confirmar resolución DNS, conexión TLS y salida por `443`.

## Validar archivo de variables

```bash
cat /opt/instana/collector/config/config.env
```

No compartir el valor real de:

```text
INSTANA_KEY
```

## Validar configuración de zona

```bash
grep -n "INSTANA_ZONE\|INSTANA_OTEL_SERVICE_NAME" \
/opt/instana/collector/config/config.env
```

```bash
grep -n -A 8 -B 3 "host.zone" \
/opt/instana/collector/config/config.yaml
```

## Reiniciar después de un cambio

```bash
cd /opt/instana/collector/bin

./instana_supervisor_service.sh restart
./instana_supervisor_service.sh status
```

Después del reinicio, esperar aproximadamente 5 minutos y volver a validar en Instana.

---

# 26. Referencias oficiales

Instana Distribution of OpenTelemetry Collector:

https://www.ibm.com/docs/en/instana-observability/saas?topic=collectors-instana-distribution-opentelemetry-collector-idot

Repositorio oficial:

https://github.com/instana/instana-otel-collector

Última release:

https://github.com/instana/instana-otel-collector/releases/latest

Descarga Linux AMD64:

https://github.com/instana/instana-otel-collector/releases/latest/download/instana-otel-collector-installer-latest-linux-amd64.sh

Descarga Linux s390x:

https://github.com/instana/instana-otel-collector/releases/latest/download/instana-otel-collector-installer-latest-linux-s390x.sh

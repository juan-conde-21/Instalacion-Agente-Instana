# Instalación de Instana Distribution of OpenTelemetry Collector (IDOT) en Windows Server

## 1. Objetivo

Esta guía describe la instalación y configuración de **Instana Distribution of OpenTelemetry Collector (IDOT)** en Windows Server utilizando el paquete ZIP oficial.

En esta guía se cubre:

- Descarga de la última versión disponible.
- Instalación manual del collector.
- Configuración mediante `config.env`.
- Identificación del host en Instana.
- Asignación de una zona mediante `host.zone`.
- Recolección de métricas del sistema.
- Recolección de Windows Event Log.
- Ingesta de logs desde archivos locales.
- Ejecución del collector como servicio de Windows.
- Validación de la información en Instana.

> **Importante:** esta guía utiliza como escenario principal el envío directo desde IDOT hacia el backend SaaS de Instana. El Instana Host Agent **no es obligatorio** para este esquema. Al final del documento se incluye una variante opcional para enviar la telemetría primero a un Instana Host Agent local.

---

## 2. Arquitectura

### Escenario principal: IDOT directo al backend de Instana

```text
Windows Server
      |
      |-- Métricas del sistema
      |-- Procesos
      |-- Windows Event Log
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

IDOT puede trabajar de manera independiente. No es necesario tener instalado el Instana Host Agent para enviar telemetría hacia el backend de Instana.

---

## 3. Descargar la última versión para Windows

Descargar siempre el paquete identificado como `latest` para Windows AMD64:

**Descarga directa:**

https://github.com/instana/instana-otel-collector/releases/latest/download/instana-otel-collector-installer-latest-windows-amd64.zip

También se pueden consultar las releases desde:

https://github.com/instana/instana-otel-collector/releases/latest

El archivo descargado debe tener un nombre similar a:

```text
instana-otel-collector-installer-latest-windows-amd64.zip
```

Así el procedimiento siempre utiliza la versión más reciente y no queda amarrado a una versión específica de IDOT.

---

## 4. Descomprimir el paquete

Crear la siguiente carpeta si no existe:

```text
C:\Program Files\Instana
```

Desde el Explorador de Windows:

1. Ubicar el archivo ZIP descargado.
2. Clic derecho sobre el archivo.
3. Seleccionar **Extract All / Extraer todo**.
4. Indicar como destino:

```text
C:\Program Files\Instana\
```

Después de la extracción se debe obtener una estructura similar a:

```text
C:\Program Files\Instana\instana-collector
├── bin
├── config
└── logs
```

Validar desde CMD:

```cmd
cd "C:\Program Files\Instana\instana-collector"
dir
```

Luego validar los ejecutables y scripts:

```cmd
cd "C:\Program Files\Instana\instana-collector\bin"
dir
```

Se deben visualizar archivos similares a:

```text
install-service.bat
instana-otelcol.exe
service-status.bat
setenv.bat
start-service.bat
start.bat
status.bat
stop-service.bat
stop.bat
uninstall-service.bat
```

---

## 5. Crear el archivo `config.env`

Para esta guía **no utilizaremos `setenv.bat` para generar el archivo**.

Vamos a trabajar directamente con:

```text
C:\Program Files\Instana\instana-collector\config\config.env
```

Abrir CMD como Administrador y ejecutar:

```cmd
notepad "C:\Program Files\Instana\instana-collector\config\config.env"
```

Si el archivo no existe, Notepad solicitará crearlo.

Utilizar la siguiente plantilla:

```properties
# ==========================================================
# INSTANA IDOT - CONFIGURACION WINDOWS
# ==========================================================

# Version del collector instalado.
# Reemplazar por la version descargada, por ejemplo 1.320.3.
INSTANA_OTEL_SERVICE_VERSION=<VERSION_IDOT>

# Endpoint OTLP gRPC del tenant Instana.
INSTANA_OTEL_ENDPOINT_GRPC=otlp-grpc-<REGION>-saas.instana.io:443

# Endpoint OTLP HTTP del tenant Instana.
# Para conexion directa al backend SaaS utilizar HTTPS.
INSTANA_OTEL_ENDPOINT_HTTP=https://otlp-http-<REGION>-saas.instana.io:443

# Metodo de comunicacion.
INSTANA_COMM_PROVIDER=instana

# Agent Key del tenant.
INSTANA_KEY=<INSTANA_AGENT_KEY>

# Hostname que identificara al servidor.
# Se recomienda conservar el hostname real del sistema operativo.
HOSTNAME=<WINDOWS_HOSTNAME>

# Nivel de log del collector: debug, info, warn o error.
INSTANA_OTEL_LOG_LEVEL=info

# ==========================================================
# IDENTIFICACION DEL HOST EN INSTANA
# ==========================================================

# Nombre del servicio OpenTelemetry asociado al collector.
INSTANA_OTEL_SERVICE_NAME=IDOT-Windows

# Zona logica que se mostrara en Infrastructure Map.
# Ejemplos: Produccion-Lima, QA-Lima, Datacenter-Principal.
INSTANA_ZONE=<ZONA_INSTANA>
```

### Ejemplo

```properties
INSTANA_OTEL_SERVICE_VERSION=1.320.3
INSTANA_OTEL_ENDPOINT_GRPC=otlp-grpc-coral-saas.instana.io:443
INSTANA_OTEL_ENDPOINT_HTTP=https://otlp-http-coral-saas.instana.io:443
INSTANA_COMM_PROVIDER=instana
INSTANA_KEY=<INSTANA_AGENT_KEY>
HOSTNAME=WIN-SERVER01
INSTANA_OTEL_LOG_LEVEL=info

INSTANA_OTEL_SERVICE_NAME=IDOT-Windows
INSTANA_ZONE=Produccion-Lima
```

> **Seguridad:** nunca almacenar un Agent Key real en un repositorio público, capturas de pantalla o documentación compartida. Utilizar siempre un placeholder como `<INSTANA_AGENT_KEY>`.

---

## 6. Entender las variables principales

| Variable | Uso |
|---|---|
| `INSTANA_OTEL_SERVICE_VERSION` | Identifica la versión del collector mostrada en la telemetría interna. |
| `INSTANA_OTEL_ENDPOINT_GRPC` | Endpoint OTLP gRPC correspondiente al tenant Instana. |
| `INSTANA_OTEL_ENDPOINT_HTTP` | Endpoint OTLP HTTP utilizado por el exporter para enviar telemetría. |
| `INSTANA_KEY` | Agent Key utilizado para autenticación contra el backend de Instana. |
| `HOSTNAME` | Nombre del host utilizado para identificar y correlacionar el servidor. |
| `INSTANA_OTEL_SERVICE_NAME` | Nombre legible del servicio OpenTelemetry del collector. |
| `INSTANA_ZONE` | Variable utilizada por esta plantilla para asignar el atributo OpenTelemetry `host.zone`. |
| `INSTANA_OTEL_LOG_LEVEL` | Nivel de logging interno del collector. |

Con:

```properties
HOSTNAME=WIN-SERVER01
INSTANA_OTEL_SERVICE_NAME=IDOT-Windows
```

la entidad puede visualizarse en Instana de forma similar a:

```text
WIN-SERVER01@IDOT-Windows
```

---

# 7. Configurar `config.yaml`

El archivo se encuentra en:

```text
C:\Program Files\Instana\instana-collector\config\config.yaml
```

Antes de modificarlo, crear una copia de respaldo:

```cmd
copy "C:\Program Files\Instana\instana-collector\config\config.yaml" "C:\Program Files\Instana\instana-collector\config\config.yaml.bak"
```

Abrir el archivo:

```cmd
notepad "C:\Program Files\Instana\instana-collector\config\config.yaml"
```

> Para evitar depender de números de línea que pueden cambiar entre versiones de IDOT, las modificaciones se identifican por **sección y bloque YAML**.

---

## 8. Agregar la zona del host

Instana utiliza atributos OpenTelemetry para determinar la zona del host.

Para servidores on-premises utilizaremos:

```text
host.zone
```

La variable definida previamente:

```properties
INSTANA_ZONE=Produccion-Lima
```

será consumida desde `config.yaml`.

### 8.1 Modificar `processors > resource/host`

Buscar dentro de:

```yaml
processors:
```

el bloque:

```yaml
resource/host:
```

Debe quedar de la siguiente manera:

```yaml
  resource/host:
    attributes:
      # Nombre del servicio del collector
      - key: service.name
        value: ${env:INSTANA_OTEL_SERVICE_NAME:-otel-collector}
        action: upsert

      # Nombre del host
      - key: host.name
        value: ${env:HOSTNAME:-hostname}
        action: upsert

      # Zona del host utilizada por Instana Infrastructure Map
      - key: host.zone
        value: ${env:INSTANA_ZONE:-Undefined}
        action: upsert
```

Con esto, la telemetría recolectada directamente desde el servidor recibirá:

```text
host.name = <HOSTNAME>
host.zone = <INSTANA_ZONE>
service.name = <INSTANA_OTEL_SERVICE_NAME>
```

---

## 9. Agregar un processor de zona para tráfico OTLP

Inmediatamente después de `resource/host`, agregar:

```yaml
  resource/zone:
    attributes:
      - key: host.zone
        value: ${env:INSTANA_ZONE}
        action: upsert
```

El bloque completo debe verse de forma similar a:

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

Usamos un processor separado para la zona en los pipelines OTLP. Así evitamos reemplazar el `service.name` de aplicaciones que ya envían su propia telemetría OpenTelemetry.

---

## 10. Aplicar la zona a los pipelines OTLP

Buscar:

```yaml
service:
  pipelines:
```

y modificar los pipelines OTLP.

### Traces

Cambiar:

```yaml
processors: [batch]
```

por:

```yaml
processors: [resource/zone, batch]
```

El pipeline debe quedar:

```yaml
    traces/otlp:
      receivers: [otlp/receiver]
      processors: [resource/zone, batch]
      exporters: [otlphttp/exporter]
```

### Logs OTLP

Debe quedar:

```yaml
    logs/otlp:
      receivers: [otlp/receiver]
      processors: [transform/severity_parse, resource/zone, batch]
      exporters: [otlphttp/exporter]
```

### Métricas OTLP

Debe quedar:

```yaml
    metrics/otlp:
      receivers: [otlp/receiver]
      processors: [resource/zone, batch]
      exporters: [otlphttp/exporter]
```

Esto es importante porque un processor solo modifica los datos de los pipelines donde está asociado.

---

## 11. Pipelines del propio servidor

Para la información recolectada directamente desde Windows, utilizar `resource/host`.

### Logs

```yaml
    logs/collector:
      receivers: [filelog, windowseventlog/system]
      processors: [resource/host, transform/severity_parse, batch]
      exporters: [otlphttp/exporter]
```

### Métricas

```yaml
    metrics/collector:
      receivers: [hostmetrics]
      processors: [resource/host, batch]
      exporters: [otlphttp/exporter]
```

No es necesario agregar simultáneamente `resource/host` y `resource/zone` en estos dos pipelines, ya que `resource/host` ya incorpora `host.zone`.

---

# 12. Configurar las rutas de logs a ingerir

La recolección de archivos se configura en:

```yaml
receivers:
  filelog:
```

En el archivo original se encuentra un bloque similar a:

```yaml
  filelog:
    include: ["C:\\ProgramData\\**\\logs\\*.log"]
    include_file_path: true
```

## Una ruta

Para leer una ruta específica:

```yaml
  filelog:
    include:
      - 'C:\Aplicacion\logs\*.log'
    include_file_path: true
```

## Varias rutas

Para leer logs desde múltiples aplicaciones o unidades:

```yaml
  filelog:
    include:
      - 'C:\Aplicacion1\logs\*.log'
      - 'C:\Aplicacion2\logs\*.log'
      - 'D:\Middleware\logs\*.log'
    include_file_path: true
```

## Incluir subdirectorios

Ejemplo:

```yaml
  filelog:
    include:
      - 'C:\Aplicacion\logs\**\*.log'
    include_file_path: true
```

La diferencia principal es:

```text
*.log
```

lee los archivos `.log` directamente en la carpeta indicada.

Mientras:

```text
**\*.log
```

permite incluir subdirectorios.

> Se recomienda utilizar comillas simples en las rutas Windows. De esta forma no es necesario escribir `\\` para representar cada barra invertida.

### Validar permisos

El servicio de IDOT debe tener permisos de lectura sobre las carpetas y archivos configurados.

Antes de considerar un problema del collector, validar que:

- La ruta exista.
- Los archivos tengan información nueva.
- La cuenta que ejecuta el servicio pueda leerlos.
- El patrón configurado coincida con el nombre real de los archivos.

---

## 13. Windows Event Log

La configuración base también incluye:

```yaml
  windowseventlog/system:
    channel: system
```

y el receiver se encuentra asociado al pipeline:

```yaml
    logs/collector:
      receivers: [filelog, windowseventlog/system]
```

Por lo tanto, además de los archivos definidos en `filelog`, IDOT recolectará eventos del canal **System** de Windows.

---

# 14. Configurar el exporter hacia Instana SaaS

Para envío directo hacia Instana SaaS, el bloque recomendado es:

```yaml
exporters:
  otlphttp/exporter:
    endpoint: ${env:INSTANA_OTEL_ENDPOINT_HTTP:-http://localhost:4318}
    headers:
      x-instana-key: ${env:INSTANA_KEY:-instanalocal}
      x-instana-host: ${env:HOSTNAME:-hostname}
    tls:
      insecure: false
      insecure_skip_verify: false
```

Para un backend SaaS se recomienda validar el certificado TLS y mantener:

```yaml
insecure: false
insecure_skip_verify: false
```

---

# 15. Iniciar IDOT

Abrir **CMD como Administrador**.

Ejecutar:

```cmd
cd "C:\Program Files\Instana\instana-collector\bin"
```

Iniciar el collector:

```cmd
start.bat
```

En una primera ejecución, el script puede crear el servicio:

```text
InstanaOTelCollector
```

y luego iniciarlo.

Resultado esperado:

```text
Service started successfully.
STATE : 4  RUNNING
```

---

## 16. Validar el estado

Ejecutar:

```cmd
status.bat
```

Resultado esperado:

```text
STATE : 4  RUNNING
```

Para información más detallada:

```cmd
service-status.bat
```

También puede validarse con:

```cmd
sc query InstanaOTelCollector
```

o abriendo:

```cmd
services.msc
```

---

## 17. Reiniciar después de cambios

Después de modificar:

```text
config.env
```

o:

```text
config.yaml
```

reiniciar el collector:

```cmd
cd "C:\Program Files\Instana\instana-collector\bin"

stop.bat
start.bat
status.bat
```

---

# 18. Validar en Instana

En **Infrastructure Map**, el host debe aparecer dentro de la zona configurada.

Ejemplo:

```text
Produccion-Lima
└── OTelHost
    └── WIN-SERVER01@IDOT-Windows
```

En los **Resource attributes** validar principalmente:

```text
host.name
WIN-SERVER01

host.zone
Produccion-Lima

service.name
IDOT-Windows

service.instance.id
WIN-SERVER01
```

Si `host.zone` no llega a la telemetría, Instana puede colocar la entidad en:

```text
Undefined Zone
```

Instana evalúa la zona utilizando, en orden de prioridad:

1. `cloud.availability_zone`
2. `host.zone`
3. `deployment.environment`

Para servidores Windows on-premises, esta guía utiliza:

```text
host.zone
```

La zona también puede buscarse en Instana mediante:

```text
entity.zone:"Produccion-Lima"
```

---

# 19. Troubleshooting

## El servicio no inicia

Validar:

```cmd
status.bat
```

y:

```cmd
service-status.bat
```

Revisar también:

```text
C:\Program Files\Instana\instana-collector\logs
```

---

## Activar debug

Editar:

```text
C:\Program Files\Instana\instana-collector\config\config.env
```

y cambiar:

```properties
INSTANA_OTEL_LOG_LEVEL=info
```

por:

```properties
INSTANA_OTEL_LOG_LEVEL=debug
```

Reiniciar:

```cmd
stop.bat
start.bat
```

Después de finalizar el troubleshooting, regresar a:

```properties
INSTANA_OTEL_LOG_LEVEL=info
```

---

## El host aparece en `Undefined Zone`

Validar primero:

```properties
INSTANA_ZONE=Produccion-Lima
```

Luego confirmar en `config.yaml`:

```yaml
- key: host.zone
  value: ${env:INSTANA_ZONE}
  action: upsert
```

y verificar que el processor correspondiente esté agregado al pipeline que genera la telemetría.

Después reiniciar:

```cmd
stop.bat
start.bat
status.bat
```

---

## Solo se ingiere la primera ruta de logs

Revisar que todas las rutas estén dentro del mismo arreglo `include`:

```yaml
filelog:
  include:
    - 'C:\App1\logs\*.log'
    - 'C:\App2\logs\*.log'
    - 'D:\App3\logs\*.log'
```

Validar además permisos y existencia de archivos en cada ruta.

Para diagnóstico puede habilitarse:

```properties
INSTANA_OTEL_LOG_LEVEL=debug
```

y revisar los logs del collector.

---

# 20. Escenario opcional: enviar IDOT a un Instana Host Agent local

IDOT también puede enviar traces, metrics y logs a un **Instana Host Agent instalado en el mismo servidor**.

El flujo sería:

```text
Aplicaciones / Windows
        |
        v
      IDOT
        |
        | OTLP
        v
Instana Host Agent
        |
        v
Instana Backend
```

El Host Agent escucha por defecto en localhost:

```text
OTLP/gRPC : 127.0.0.1:4317
OTLP/HTTP : 127.0.0.1:4318
```

Para utilizar este modo, modificar `config.env`:

```properties
INSTANA_OTEL_ENDPOINT_GRPC=http://127.0.0.1:4317
INSTANA_OTEL_ENDPOINT_HTTP=http://127.0.0.1:4318
```

Y ajustar el exporter:

```yaml
exporters:
  otlphttp/exporter:
    endpoint: ${env:INSTANA_OTEL_ENDPOINT_HTTP}
    tls:
      insecure: true
```

Para este escenario se utiliza `http://`, ya que la conexión local hacia el Host Agent no utiliza TLS de manera predeterminada.

El Host Agent debe tener habilitada la recepción de OpenTelemetry. En versiones recientes esta capacidad está habilitada por defecto; si fuera necesario, puede validarse en su `configuration.yaml`.

> Si no existe Instana Host Agent en el servidor, utilizar el escenario principal de esta guía: **IDOT → Instana Backend**.

---

# 21. Referencias oficiales

- Instana Distribution of OpenTelemetry Collector (IDOT):  
  https://www.ibm.com/docs/en/instana-observability/saas?topic=collectors-instana-distribution-opentelemetry-collector-idot

- Repositorio oficial IDOT:  
  https://github.com/instana/instana-otel-collector

- Releases oficiales:  
  https://github.com/instana/instana-otel-collector/releases/latest

- Envío de OpenTelemetry al Instana Agent:  
  https://www.ibm.com/docs/en/instana-observability?topic=instana-agent

- Envío de OpenTelemetry al backend de Instana:  
  https://www.ibm.com/docs/en/instana-observability?topic=instana-backend

- Configuración de zonas para OTelHost:  
  https://www.ibm.com/docs/en/instana-observability/1.0.300?topic=entities-otelhost

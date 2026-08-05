# Recolección de logs de NGINX Stream con OpenTelemetry Filelog Receiver e Instana

## 1. Objetivo

Este procedimiento documenta la instalación y configuración de **OpenTelemetry Collector Contrib** para leer logs personalizados de **NGINX Stream**, procesarlos y enviarlos al agente local de **IBM Instana** mediante el protocolo **OTLP/gRPC**.

El caso fue validado con la siguiente arquitectura:

```text
NGINX Stream
   |
   | escribe sesiones TCP/UDP
   v
/var/log/nginx/stream_access.log
   |
   | Filelog Receiver
   v
OpenTelemetry Collector Contrib
   |
   | Batch Processor
   v
OTLP/gRPC - localhost:4317
   |
   v
Agente Instana
   |
   v
Backend de Instana
```

El propósito de esta integración es complementar el monitoreo de NGINX Stream con información operativa por sesión, como:

- IP de origen.
- Protocolo TCP o UDP.
- Estado de la sesión.
- Bytes enviados y recibidos.
- Duración de la sesión.
- Servidor upstream seleccionado.
- Tiempo de conexión al upstream.
- Dirección recibida mediante PROXY Protocol, cuando aplique.

> NGINX Stream trabaja en capa 4. Por ello, estos registros no contienen URL, métodos HTTP o códigos HTTP de una aplicación. La información corresponde a sesiones TCP/UDP.

---

## 2. ¿Qué es OpenTelemetry?

OpenTelemetry, también llamado **OTel**, es un estándar abierto para recolectar, procesar y enviar telemetría:

- Logs.
- Métricas.
- Trazas.

En este caso se utiliza el **OpenTelemetry Collector**, un servicio independiente que lee información, la procesa y luego la exporta hacia Instana.

El Collector se organiza en cuatro bloques principales:

```text
Receiver -> Processor -> Exporter -> Pipeline
```

| Componente | Función en este caso |
|---|---|
| Receiver | Lee el archivo de log de NGINX. |
| Processor | Agrupa los registros antes de enviarlos. |
| Exporter | Envía los registros al agente Instana. |
| Pipeline | Conecta receiver, processor y exporter en el orden correcto. |

Se utiliza la distribución **Contrib** porque incluye componentes adicionales, entre ellos el `filelog receiver`.

---

## 3. Ambiente validado

El procedimiento fue validado en un servidor Linux con:

```text
NGINX: nginx/1.29.0 (nginx-plus-r35-p2)
OpenTelemetry Collector Contrib: 0.158.0
Destino OTLP: agente Instana local
Puerto OTLP/gRPC: 4317
Log monitoreado: /var/log/nginx/stream_access.log
```

La estructura es aplicable a otras versiones compatibles del Collector Contrib, pero siempre se recomienda validar la sintaxis con la versión instalada.

---

## 4. Formato de log de NGINX Stream

NGINX se encontraba configurado con un formato personalizado similar al siguiente:

```nginx
stream {
    log_format stream_log
        '$remote_addr [$time_local] '
        '$protocol $status '
        '$bytes_sent $bytes_received '
        '$session_time '
        '$upstream_addr '
        '$upstream_connect_time'
        'PROXY_PROTOCOL=$proxy_protocol_addr';

    access_log /var/log/nginx/stream_access.log stream_log;
    error_log  /var/log/nginx/stream_error.log;
}
```

Ejemplo de una línea generada:

```text
172.21.102.122 [04/Aug/2026:17:27:36 -0500] TCP 200 3410 418 10.012 172.27.1.92:443 0.001PROXY_PROTOCOL=-
```

Interpretación:

| Campo | Ejemplo | Significado |
|---|---|---|
| Cliente | `172.21.102.122` | IP que inició la conexión hacia NGINX. |
| Fecha | `04/Aug/2026:17:27:36 -0500` | Fecha, hora y zona horaria. |
| Protocolo | `TCP` | Protocolo administrado por NGINX Stream. |
| Estado | `200` | Resultado de la sesión Stream. No es un HTTP 200. |
| Bytes enviados | `3410` | Datos enviados por NGINX hacia el cliente. |
| Bytes recibidos | `418` | Datos recibidos desde el cliente. |
| Duración | `10.012` | Duración de la sesión en segundos. |
| Upstream | `172.27.1.92:443` | Servidor de destino seleccionado. |
| Tiempo de conexión | `0.001` | Tiempo de conexión al upstream. |
| PROXY Protocol | `-` | No se recibió una dirección mediante PROXY Protocol. |

### Corrección opcional del formato

Actualmente no existe un espacio entre `$upstream_connect_time` y `PROXY_PROTOCOL`.

Se genera:

```text
0.001PROXY_PROTOCOL=-
```

Puede corregirse así:

```nginx
'$upstream_connect_time '
'PROXY_PROTOCOL=$proxy_protocol_addr';
```

La configuración de OpenTelemetry incluida más adelante contempla ambas variantes.

---

## 5. Prerrequisitos

Antes de instalar el Collector se debe contar con:

1. Agente Instana instalado y reportando.
2. Recepción OpenTelemetry habilitada en el agente.
3. Puerto local `4317` disponible para OTLP/gRPC.
4. Acceso administrativo al servidor.
5. Ruta exacta de los logs que serán recolectados.
6. OpenTelemetry Collector Contrib versión `0.110.0` o posterior.

### Verificar el agente Instana

```bash
sudo systemctl status instana-agent --no-pager
```

### Verificar el puerto OTLP/gRPC

```bash
sudo ss -lntp | grep ':4317'
```

Resultado esperado:

```text
LISTEN ... 127.0.0.1:4317 ...
```

El agente Instana normalmente escucha en `localhost`. Por ello, cuando el Collector está en el mismo servidor se utiliza:

```text
localhost:4317
```

### Habilitar explícitamente OTLP en el agente Instana

Cuando sea necesario, revisar el archivo:

```text
/opt/instana/agent/etc/instana/configuration.yaml
```

Configuración:

```yaml
com.instana.plugin.opentelemetry:
  grpc:
    enabled: true
    port: 4317
  http:
    enabled: true
    port: 4318
```

Reiniciar el agente después de cualquier cambio:

```bash
sudo systemctl restart instana-agent
```

---

## 6. Instalación de OpenTelemetry Collector Contrib

Descargar el paquete correspondiente desde las publicaciones oficiales de OpenTelemetry Collector Releases.

Seleccionar correctamente:

- Sistema operativo.
- Arquitectura.
- Tipo de paquete.
- Versión.

Ejemplos:

```text
otelcol-contrib_<VERSION>_linux_amd64.rpm
otelcol-contrib_<VERSION>_linux_amd64.deb
```

### RHEL, Rocky Linux, AlmaLinux, Oracle Linux o CentOS

```bash
sudo rpm -Uvh otelcol-contrib_<VERSION>_linux_amd64.rpm
```

También puede instalarse con:

```bash
sudo dnf install -y ./otelcol-contrib_<VERSION>_linux_amd64.rpm
```

### Ubuntu o Debian

```bash
sudo dpkg -i otelcol-contrib_<VERSION>_linux_amd64.deb
```

### Verificar la versión instalada

```bash
otelcol-contrib --version
```

### Verificar el servicio

```bash
sudo systemctl status otelcol-contrib --no-pager
```

### Rutas normalmente utilizadas

```text
Binario:
  /usr/bin/otelcol-contrib

Configuración:
  /etc/otelcol-contrib/config.yaml

Servicio:
  otelcol-contrib.service
```

La ruta puede variar según el paquete o la distribución. Puede confirmarse con:

```bash
sudo systemctl cat otelcol-contrib
```

---

## 7. Permisos de lectura sobre los logs

El Collector necesita:

- Permiso de lectura sobre el archivo.
- Permiso de ejecución o recorrido sobre los directorios que conforman la ruta.

En el caso implementado se habilitó lectura para otros usuarios mediante:

```bash
sudo chmod o+r /var/log/nginx/*.log
```

Validar:

```bash
ls -l /var/log/nginx/*.log
```

Ejemplo esperado:

```text
-rw-r--r--. 1 root root ... stream_access.log
```

### Validar toda la ruta

```bash
namei -l /var/log/nginx/stream_access.log
```

El usuario del Collector debe poder atravesar:

```text
/var
/var/log
/var/log/nginx
```

Si el directorio `/var/log/nginx` no permite recorrido, podría requerirse:

```bash
sudo chmod o+x /var/log/nginx
```

No debe aplicarse este cambio sin revisar previamente los permisos existentes.

### Confirmar lectura con el usuario del Collector

Primero identificar el usuario efectivo:

```bash
sudo systemctl show otelcol-contrib -p User -p Group
```

Si el servicio usa `otelcol-contrib`:

```bash
sudo -u otelcol-contrib head -n 1 /var/log/nginx/stream_access.log
```

Si el comando muestra una línea del archivo, el acceso es correcto.

### Consideración de seguridad

`chmod o+r` permite que cualquier usuario local pueda leer el archivo.

Fue utilizado en este caso por simplicidad y porque era el mecanismo autorizado para la implementación. Para ambientes con mayores restricciones se recomienda evaluar:

- Grupo compartido.
- ACL.
- Permisos administrados mediante `logrotate`.
- Ejecución del Collector con un grupo suplementario.

---

## 8. Configuración base validada

Respaldar primero el archivo original:

```bash
sudo cp -p \
  /etc/otelcol-contrib/config.yaml \
  /etc/otelcol-contrib/config.yaml.bak.$(date +%Y%m%d-%H%M%S)
```

Editar:

```bash
sudo vi /etc/otelcol-contrib/config.yaml
```

Configuración base:

```yaml
receivers:
  filelog/nginx_stream:
    include:
      - /var/log/nginx/stream_access.log

    start_at: end
    include_file_name: true
    include_file_path: true

processors:
  batch: {}

exporters:
  otlp/instana_agent:
    endpoint: "localhost:4317"
    tls:
      insecure: true

service:
  pipelines:
    logs/nginx_stream:
      receivers:
        - filelog/nginx_stream
      processors:
        - batch
      exporters:
        - otlp/instana_agent
```

---

## 9. Explicación detallada de `config.yaml`

### 9.1 Receiver

```yaml
receivers:
  filelog/nginx_stream:
```

`receivers` define cómo ingresan los datos al Collector.

`filelog/nginx_stream` significa:

```text
Tipo de receiver: filelog
Nombre lógico: nginx_stream
```

El nombre después de `/` puede personalizarse. Permite tener varios receivers del mismo tipo:

```yaml
filelog/nginx_stream:
filelog/aplicacion_java:
filelog/nginx_segundo:
```

### 9.2 Ruta `include`

```yaml
include:
  - /var/log/nginx/stream_access.log
```

Indica qué archivo debe leer el Collector.

Puede utilizar:

- Un archivo exacto.
- Varias rutas.
- Comodines.

Ejemplos:

```yaml
include:
  - /var/log/nginx/stream_access.log
```

```yaml
include:
  - /var/log/nginx/*.log
```

```yaml
include:
  - /var/log/nginx/stream_*.log
  - /opt/aplicacion/logs/*.log
```

Debe evitarse un patrón demasiado amplio si puede incluir archivos innecesarios o sensibles.

### 9.3 `start_at`

```yaml
start_at: end
```

Determina desde qué posición comienza a leer un archivo cuando lo descubre.

Valores:

| Valor | Comportamiento |
|---|---|
| `end` | Lee únicamente registros nuevos. |
| `beginning` | Lee el archivo desde la primera línea. |

Para producción se utilizó:

```yaml
start_at: end
```

Esto evita enviar todo el histórico del archivo durante la primera ejecución.

Importante: después de iniciar el Collector debe generarse una nueva línea en el log para validar la integración.

### 9.4 Nombre y ruta del archivo

```yaml
include_file_name: true
include_file_path: true
```

Agrega atributos al registro:

```text
log.file.name
log.file.path
```

Ejemplo:

```text
log.file.name = stream_access.log
log.file.path = /var/log/nginx/stream_access.log
```

Esto facilita identificar el origen cuando un mismo Collector lee varios archivos.

### 9.5 Processor `batch`

```yaml
processors:
  batch: {}
```

El processor `batch` agrupa varios registros antes de enviarlos.

Sin batch:

```text
Log 1 -> envío
Log 2 -> envío
Log 3 -> envío
```

Con batch:

```text
Log 1
Log 2  -> un envío agrupado
Log 3
```

Sus beneficios son:

- Reduce la cantidad de llamadas hacia el destino.
- Mejora la eficiencia de red.
- Reduce el procesamiento por envío.
- Permite controlar el tamaño y frecuencia de los lotes.

Cuando se configura:

```yaml
batch: {}
```

se utilizan los valores predeterminados de la versión instalada.

En versiones actuales del Collector, los valores predeterminados documentados son aproximadamente:

```yaml
batch:
  timeout: 200ms
  send_batch_size: 8192
  send_batch_max_size: 0
```

Significado:

| Parámetro | Significado |
|---|---|
| `timeout` | Envía el lote cuando transcurre ese tiempo, aunque no se alcance el tamaño. |
| `send_batch_size` | Cantidad de registros que activa un envío. |
| `send_batch_max_size` | Límite máximo del lote. `0` significa sin límite explícito. |

`send_batch_size` es un disparador, no un límite estricto.

Ejemplo:

```yaml
batch/nginx:
  timeout: 1s
  send_batch_size: 100
  send_batch_max_size: 200
```

En este ejemplo el lote se envía cuando:

- Se acumulan 100 registros, o
- Transcurre 1 segundo.

Además, ningún lote tendrá más de 200 registros.

Para un volumen moderado puede mantenerse:

```yaml
batch: {}
```

Para escenarios con alto volumen o presión sobre el agente, conviene establecer valores explícitos.

### 9.6 Exporter OTLP

```yaml
exporters:
  otlp/instana_agent:
```

El exporter determina el destino de los datos.

`otlp/instana_agent` significa:

```text
Tipo: OTLP/gRPC
Nombre lógico: instana_agent
```

### 9.7 Endpoint

```yaml
endpoint: "localhost:4317"
```

Indica que el Collector envía los datos al agente Instana instalado en el mismo servidor.

El puerto `4317` corresponde a:

```text
OTLP sobre gRPC
```

Cuando el agente está en otro servidor, debe evaluarse si escucha en una interfaz remota. Por defecto, el agente Instana suele escuchar únicamente en `127.0.0.1`.

### 9.8 TLS insecure

```yaml
tls:
  insecure: true
```

Se utiliza porque la comunicación ocurre localmente contra un endpoint OTLP sin TLS:

```text
Collector -> localhost:4317 -> agente Instana
```

No significa que la comunicación del agente hacia el backend Instana sea insegura.

Este valor no debe copiarse automáticamente cuando se envía directamente a un endpoint remoto con TLS.

### 9.9 Pipeline

```yaml
service:
  pipelines:
    logs/nginx_stream:
```

La pipeline conecta todos los componentes.

```yaml
receivers:
  - filelog/nginx_stream
```

Lee el archivo.

```yaml
processors:
  - batch
```

Agrupa registros.

```yaml
exporters:
  - otlp/instana_agent
```

Envía los registros al agente Instana.

El flujo completo es:

```text
filelog/nginx_stream
        |
        v
      batch
        |
        v
otlp/instana_agent
```

Un componente definido fuera de `service.pipelines` no se ejecuta.

Por ejemplo, definir `debug` en `exporters` no produce salida si no se agrega a la pipeline.

---

## 10. Validar y aplicar la configuración

### Validar sintaxis

```bash
sudo /usr/bin/otelcol-contrib validate \
  --config=/etc/otelcol-contrib/config.yaml
```

Si la configuración es válida, el comando no debe mostrar errores.

### Reiniciar el servicio

```bash
sudo systemctl restart otelcol-contrib
```

### Verificar estado

```bash
sudo systemctl status otelcol-contrib --no-pager
```

### Ver logs recientes

```bash
sudo journalctl -u otelcol-contrib -n 100 --no-pager
```

### Seguimiento en tiempo real

```bash
sudo journalctl -u otelcol-contrib -f
```

En otra consola:

```bash
sudo tail -f /var/log/nginx/stream_access.log
```

Debe generarse tráfico nuevo hacia NGINX para producir nuevas líneas.

---

## 11. Agregar otra ruta de logs en el mismo servidor

Existen dos enfoques.

### 11.1 Mismo receiver para varios archivos

Usar este enfoque cuando:

- Los archivos tienen un tratamiento similar.
- No es necesario asignar un `service.name` diferente.
- Se desea una configuración sencilla.

Ejemplo:

```yaml
receivers:
  filelog/nginx_stream:
    include:
      - /var/log/nginx/stream_access.log
      - /opt/nginx-secundario/logs/stream_access.log
      - /srv/aplicacion/logs/*.log

    start_at: end
    include_file_name: true
    include_file_path: true
```

La pipeline no cambia:

```yaml
service:
  pipelines:
    logs/nginx_stream:
      receivers:
        - filelog/nginx_stream
      processors:
        - batch
      exporters:
        - otlp/instana_agent
```

Los registros podrán diferenciarse mediante:

```text
log.file.name
log.file.path
```

También debe habilitarse lectura en las nuevas rutas:

```bash
sudo chmod o+r /opt/nginx-secundario/logs/*.log
sudo chmod o+r /srv/aplicacion/logs/*.log
```

Y validar el recorrido de directorios:

```bash
namei -l /opt/nginx-secundario/logs/stream_access.log
```

### 11.2 Receivers separados por aplicación

Usar este enfoque cuando:

- Los formatos de log son diferentes.
- Cada aplicación debe tener un nombre independiente.
- Se requieren parsers distintos.
- Se necesitan políticas de batch diferentes.
- Se desea filtrar claramente por servicio en Instana.

Ejemplo:

```yaml
receivers:
  filelog/nginx_stream:
    include:
      - /var/log/nginx/stream_access.log
    start_at: end
    include_file_name: true
    include_file_path: true

  filelog/aplicacion_backend:
    include:
      - /opt/backend/logs/application.log
    start_at: end
    include_file_name: true
    include_file_path: true

processors:
  resource/nginx_stream:
    attributes:
      - key: service.name
        value: nginx-stream
        action: upsert
      - key: service.namespace
        value: balanceadores
        action: upsert
      - key: deployment.environment
        value: desarrollo
        action: upsert

  resource/aplicacion_backend:
    attributes:
      - key: service.name
        value: aplicacion-backend
        action: upsert
      - key: service.namespace
        value: aplicaciones
        action: upsert
      - key: deployment.environment
        value: desarrollo
        action: upsert

  batch: {}

exporters:
  otlp/instana_agent:
    endpoint: "localhost:4317"
    tls:
      insecure: true

service:
  pipelines:
    logs/nginx_stream:
      receivers:
        - filelog/nginx_stream
      processors:
        - resource/nginx_stream
        - batch
      exporters:
        - otlp/instana_agent

    logs/aplicacion_backend:
      receivers:
        - filelog/aplicacion_backend
      processors:
        - resource/aplicacion_backend
        - batch
      exporters:
        - otlp/instana_agent
```

En este diseño cada pipeline agrega su propia identidad.

---

## 12. Agregar otro NGINX ubicado en otra ruta

Cuando existe otra instancia de NGINX en el mismo servidor:

```text
/var/log/nginx/stream_access.log
/opt/nginx2/logs/stream_access.log
```

Puede utilizarse un receiver por instancia:

```yaml
receivers:
  filelog/nginx_principal:
    include:
      - /var/log/nginx/stream_access.log
    start_at: end
    include_file_path: true

  filelog/nginx_secundario:
    include:
      - /opt/nginx2/logs/stream_access.log
    start_at: end
    include_file_path: true
```

Y asignar nombres diferentes mediante processors `resource`.

Esto es más recomendable que mezclar ambas instancias cuando representan servicios o ambientes distintos.

---

## 13. Logs ubicados en otro servidor

El `filelog receiver` lee archivos accesibles desde el sistema operativo donde se ejecuta.

Si NGINX está en otro servidor, lo recomendado es:

```text
Servidor NGINX A:
  Agente Instana
  OpenTelemetry Collector
  Logs locales

Servidor NGINX B:
  Agente Instana
  OpenTelemetry Collector
  Logs locales
```

No se recomienda intentar leer directamente un archivo remoto desde otro servidor, salvo que exista un filesystem montado y se hayan evaluado:

- Disponibilidad del montaje.
- Permisos.
- Latencia.
- Rotación.
- Riesgo de duplicidad.
- Pérdida temporal del filesystem.

La instalación local por servidor simplifica la correlación con el host y evita depender de montajes remotos.

---

## 14. Parsing opcional del log de NGINX Stream

La configuración base envía cada línea como texto.

Ejemplo:

```text
body = 172.21.102.122 [04/Aug/2026:17:27:36 -0500] TCP 200 ...
```

Esto es suficiente para centralizar y buscar texto.

Cuando se necesita filtrar por campos específicos, puede agregarse un `regex_parser`.

Ejemplo:

```yaml
receivers:
  filelog/nginx_stream:
    include:
      - /var/log/nginx/stream_access.log

    start_at: end
    include_file_name: true
    include_file_path: true

    operators:
      - type: regex_parser
        id: parse_nginx_stream
        on_error: send

        regex: '^(?P<client_ip>\S+) \[(?P<timestamp>[^\]]+)\] (?P<protocol>\S+) (?P<status>\d{3}) (?P<bytes_sent>\d+) (?P<bytes_received>\d+) (?P<session_time>[0-9.]+) (?P<upstream_addr>\S+) (?P<upstream_connect_time>[0-9.,-]+)\s*PROXY_PROTOCOL=(?P<proxy_protocol_addr>\S+)$'

        timestamp:
          parse_from: attributes.timestamp
          layout: '%d/%b/%Y:%H:%M:%S %z'
```

Atributos resultantes:

```text
client_ip
timestamp
protocol
status
bytes_sent
bytes_received
session_time
upstream_addr
upstream_connect_time
proxy_protocol_addr
```

El fragmento:

```regex
\s*
```

permite aceptar:

```text
0.001PROXY_PROTOCOL=-
```

y también:

```text
0.001 PROXY_PROTOCOL=-
```

### `on_error: send`

```yaml
on_error: send
```

Indica que, si una línea no coincide con la expresión regular, debe enviarse de todas formas como log sin parsear.

Esto evita perder registros por una variación inesperada del formato.

Antes de habilitar parsing en producción se recomienda probar varias muestras reales del archivo.

---

## 15. Configuración recomendada con parsing y batch explícito

Ejemplo más completo:

```yaml
receivers:
  filelog/nginx_stream:
    include:
      - /var/log/nginx/stream_access.log

    start_at: end
    include_file_name: true
    include_file_path: true

    retry_on_failure:
      enabled: true
      initial_interval: 1s
      max_interval: 30s
      max_elapsed_time: 5m

    operators:
      - type: regex_parser
        id: parse_nginx_stream
        on_error: send
        regex: '^(?P<client_ip>\S+) \[(?P<timestamp>[^\]]+)\] (?P<protocol>\S+) (?P<status>\d{3}) (?P<bytes_sent>\d+) (?P<bytes_received>\d+) (?P<session_time>[0-9.]+) (?P<upstream_addr>\S+) (?P<upstream_connect_time>[0-9.,-]+)\s*PROXY_PROTOCOL=(?P<proxy_protocol_addr>\S+)$'

        timestamp:
          parse_from: attributes.timestamp
          layout: '%d/%b/%Y:%H:%M:%S %z'

processors:
  resource/nginx_stream:
    attributes:
      - key: service.name
        value: nginx-stream
        action: upsert
      - key: service.namespace
        value: balanceadores
        action: upsert
      - key: deployment.environment
        value: desarrollo
        action: upsert

  batch/nginx:
    timeout: 1s
    send_batch_size: 100
    send_batch_max_size: 200

exporters:
  otlp/instana_agent:
    endpoint: "localhost:4317"
    tls:
      insecure: true

    timeout: 10s

    retry_on_failure:
      enabled: true
      initial_interval: 1s
      max_interval: 30s
      max_elapsed_time: 5m

service:
  pipelines:
    logs/nginx_stream:
      receivers:
        - filelog/nginx_stream
      processors:
        - resource/nginx_stream
        - batch/nginx
      exporters:
        - otlp/instana_agent
```

Esta configuración no es obligatoria para comenzar. La configuración base es suficiente para validar el flujo.

---

## 16. Persistencia de offsets

El Collector mantiene en memoria la posición hasta la que leyó cada archivo.

Para conservar offsets en disco después de reinicios puede utilizarse `file_storage`.

### Crear directorio

```bash
sudo install -d \
  -o otelcol-contrib \
  -g otelcol-contrib \
  -m 0750 \
  /var/lib/otelcol-contrib/storage
```

### Configuración

```yaml
extensions:
  file_storage:
    directory: /var/lib/otelcol-contrib/storage

receivers:
  filelog/nginx_stream:
    include:
      - /var/log/nginx/stream_access.log
    start_at: end
    storage: file_storage

service:
  extensions:
    - file_storage
```

Configuración completa simplificada:

```yaml
extensions:
  file_storage:
    directory: /var/lib/otelcol-contrib/storage

receivers:
  filelog/nginx_stream:
    include:
      - /var/log/nginx/stream_access.log
    start_at: end
    include_file_name: true
    include_file_path: true
    storage: file_storage

processors:
  batch: {}

exporters:
  otlp/instana_agent:
    endpoint: "localhost:4317"
    tls:
      insecure: true

service:
  extensions:
    - file_storage

  pipelines:
    logs/nginx_stream:
      receivers:
        - filelog/nginx_stream
      processors:
        - batch
      exporters:
        - otlp/instana_agent
```

La extensión almacena información como:

- Archivo conocido.
- Fingerprint.
- Offset leído.
- Estado del archivo.

Es recomendable cuando se busca mayor continuidad después de reinicios.

---

## 17. Rotación de logs

El Filelog Receiver puede seguir archivos rotados mediante estrategias comunes como:

- Renombrar y crear un nuevo archivo.
- Copiar y truncar el archivo original.

Sin embargo, debe garantizarse que el archivo nuevo conserve permisos de lectura.

Revisar:

```bash
sudo cat /etc/logrotate.d/nginx
```

Después de una rotación, validar:

```bash
ls -l /var/log/nginx/stream_access.log
sudo -u otelcol-contrib test -r /var/log/nginx/stream_access.log
```

La instrucción:

```bash
sudo chmod o+r /var/log/nginx/*.log
```

afecta los archivos existentes. Si `logrotate` crea un archivo nuevo con permisos más restrictivos, será necesario ajustar la política de rotación o reaplicar los permisos.

No se recomienda incluir archivos comprimidos `.gz` en el mismo patrón, salvo que se configure explícitamente la lectura de archivos comprimidos.

Ejemplo de exclusión:

```yaml
receivers:
  filelog/nginx_stream:
    include:
      - /var/log/nginx/*.log
    exclude:
      - /var/log/nginx/*.gz
```

---

## 18. Exporter `debug` para pruebas

El exporter `debug` permite ver en el journal cómo el Collector interpreta los registros.

Agregar:

```yaml
exporters:
  otlp/instana_agent:
    endpoint: "localhost:4317"
    tls:
      insecure: true

  debug:
    verbosity: detailed
```

Agregarlo temporalmente a la pipeline:

```yaml
service:
  pipelines:
    logs/nginx_stream:
      receivers:
        - filelog/nginx_stream
      processors:
        - batch
      exporters:
        - otlp/instana_agent
        - debug
```

Revisar:

```bash
sudo journalctl -u otelcol-contrib -f
```

Después de validar, retirar `debug` para evitar crecimiento innecesario del journal.

Definir el exporter sin agregarlo a la pipeline no produce ninguna salida.

---

## 19. Solución de problemas

### 19.1 `permission denied`

Síntoma:

```text
open /var/log/nginx/stream_access.log: permission denied
```

Validar:

```bash
ls -l /var/log/nginx/stream_access.log
namei -l /var/log/nginx/stream_access.log
sudo -u otelcol-contrib head -n 1 /var/log/nginx/stream_access.log
```

Aplicar, cuando esté autorizado:

```bash
sudo chmod o+r /var/log/nginx/*.log
```

El problema está en la lectura del archivo, no en Instana.

### 19.2 No aparecen logs, pero no existen errores

Revisar:

```yaml
start_at: end
```

Con `end`, solo se leen líneas nuevas.

Generar tráfico y observar:

```bash
sudo tail -f /var/log/nginx/stream_access.log
```

### 19.3 `connection refused`

Síntoma:

```text
rpc error: connection refused
```

Validar:

```bash
sudo ss -lntp | grep ':4317'
sudo systemctl status instana-agent --no-pager
```

Confirmar:

```yaml
endpoint: "localhost:4317"
```

### 19.4 `DeadlineExceeded` o `Unavailable`

Síntomas:

```text
rpc error: code = DeadlineExceeded
rpc error: code = Unavailable
Exporting failed
```

Esto indica un problema entre el Collector y el receptor OTLP del agente.

Revisar:

```bash
sudo journalctl -u otelcol-contrib -n 100 --no-pager
sudo systemctl status instana-agent --no-pager
sudo grep -Ei 'error|heap|opentelemetry|grpc' \
  /opt/instana/agent/data/log/agent.log | tail -50
```

También puede configurarse un batch más pequeño:

```yaml
batch/nginx:
  timeout: 1s
  send_batch_size: 100
  send_batch_max_size: 200
```

### 19.5 `Java heap space`

Síntoma recibido desde el agente:

```text
debug data: "Java heap space"
```

Este error corresponde al proceso Java del agente Instana, no al Filelog Receiver.

Acciones:

1. Detener temporalmente el Collector si genera reintentos continuos.
2. Revisar memoria disponible.
3. Revisar el log del agente.
4. Reiniciar el agente cuando corresponda.
5. Reducir el tamaño de batch.
6. Evaluar ajuste de memoria del agente con soporte o según la guía oficial.

### 19.6 Error de YAML

Validar:

```bash
sudo /usr/bin/otelcol-contrib validate \
  --config=/etc/otelcol-contrib/config.yaml
```

Los problemas más comunes son:

- Indentación.
- Nombre distinto entre definición y pipeline.
- Comillas incompletas.
- Tabs en lugar de espacios.
- Componentes no disponibles en la distribución instalada.

### 19.7 El parser no reconoce algunas líneas

Usar:

```yaml
on_error: send
```

Esto permite enviar la línea sin parsear.

Revisar varias muestras:

```bash
tail -n 100 /var/log/nginx/stream_access.log
```

El formato puede variar en casos de error, múltiples upstreams o valores vacíos.

---

## 20. Comandos de verificación integral

```bash
# Versión
otelcol-contrib --version

# Configuración usada por systemd
sudo systemctl cat otelcol-contrib

# Validar YAML
sudo /usr/bin/otelcol-contrib validate \
  --config=/etc/otelcol-contrib/config.yaml

# Estado del Collector
sudo systemctl status otelcol-contrib --no-pager

# Logs del Collector
sudo journalctl -u otelcol-contrib -n 100 --no-pager

# Estado del agente Instana
sudo systemctl status instana-agent --no-pager

# Puerto OTLP
sudo ss -lntp | grep ':4317'

# Permisos del log
ls -l /var/log/nginx/stream_access.log

# Permisos de toda la ruta
namei -l /var/log/nginx/stream_access.log

# Lectura con usuario del Collector
sudo -u otelcol-contrib \
  tail -n 1 /var/log/nginx/stream_access.log

# Generación de nuevas líneas
sudo tail -f /var/log/nginx/stream_access.log
```

---

## 21. Resultado esperado

Después de completar el procedimiento:

1. NGINX continúa escribiendo su log normalmente.
2. OpenTelemetry Filelog Receiver detecta líneas nuevas.
3. El processor `batch` agrupa los registros.
4. El exporter OTLP envía los registros a `localhost:4317`.
5. El agente Instana recibe y reenvía los datos.
6. Los logs quedan disponibles en Instana para búsqueda y análisis.

Para NGINX Stream se obtiene visibilidad operativa de las sesiones TCP/UDP.

No se obtienen automáticamente:

- URL.
- Método HTTP.
- Headers HTTP.
- Código HTTP real.
- Traza distribuida generada por NGINX Stream.

Para trazabilidad de extremo a extremo debe instrumentarse también la aplicación o servicio ubicado detrás del balanceador.

---

## 22. Configuración base final

```yaml
receivers:
  filelog/nginx_stream:
    include:
      - /var/log/nginx/stream_access.log

    start_at: end
    include_file_name: true
    include_file_path: true

processors:
  batch: {}

exporters:
  otlp/instana_agent:
    endpoint: "localhost:4317"
    tls:
      insecure: true

service:
  pipelines:
    logs/nginx_stream:
      receivers:
        - filelog/nginx_stream
      processors:
        - batch
      exporters:
        - otlp/instana_agent
```

Permiso aplicado en el caso validado:

```bash
sudo chmod o+r /var/log/nginx/*.log
```

Aplicación:

```bash
sudo /usr/bin/otelcol-contrib validate \
  --config=/etc/otelcol-contrib/config.yaml

sudo systemctl restart otelcol-contrib
sudo systemctl status otelcol-contrib --no-pager
sudo journalctl -u otelcol-contrib -f
```

---

## 23. Referencias

- [IBM Instana: Collecting Linux system logs with OpenTelemetry](https://www.ibm.com/docs/en/instana-observability?topic=opentelemetry-collecting-linux-system-logs)
- [IBM Instana: Sending OpenTelemetry data to the Instana agent](https://www.ibm.com/docs/en/instana-observability?topic=instana-agent)
- [IBM Instana: OpenTelemetry logging best practices](https://www.ibm.com/docs/en/instana-observability?topic=logs-opentelemetry-logging-best-practices)
- [OpenTelemetry: Collector configuration](https://opentelemetry.io/docs/collector/configuration/)
- [OpenTelemetry Collector Contrib: File Log Receiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/filelogreceiver)
- [OpenTelemetry Collector: Batch Processor](https://github.com/open-telemetry/opentelemetry-collector/tree/main/processor/batchprocessor)
- [OpenTelemetry Collector Contrib: File Storage Extension](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/extension/storage/filestorage)
- [NGINX: Stream Log Module](https://nginx.org/en/docs/stream/ngx_stream_log_module.html)

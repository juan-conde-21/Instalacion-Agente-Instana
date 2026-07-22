# Habilitación del sensor SAP ABAP en IBM Instana

Este procedimiento describe cómo habilitar el sensor SAP ABAP mediante el agente de host de IBM Instana y la librería SAP Java Connector (SAP JCo).

Incluye validaciones previas, identificación de las variables SAP, instalación de SAP JCo, configuración local y remota, conexión mediante SAP Message Server, validación, diagnóstico y rollback.

> [!IMPORTANT]
> El sensor SAP ABAP requiere **SAP JCo 3.1.8 o superior**. Los ejemplos de este procedimiento utilizan **SAP JCo 3.1.13**. Reemplace la versión en las rutas y comandos cuando utilice otro patch.

## Contenido

1. [Documentación de referencia](#1-documentación-de-referencia)
2. [Arquitectura de conexión](#2-arquitectura-de-conexión)
3. [Prerrequisitos](#3-prerrequisitos)
4. [Información requerida](#4-información-requerida)
5. [Validaciones previas](#5-validaciones-previas)
6. [Descarga de SAP JCo](#6-descarga-de-sap-jco)
7. [Instalación de SAP JCo](#7-instalación-de-sap-jco)
8. [Autorizaciones del usuario SAP](#8-autorizaciones-del-usuario-sap)
9. [Configuración del sensor](#9-configuración-del-sensor)
10. [Aplicación de la configuración](#10-aplicación-de-la-configuración)
11. [Validación en Instana](#11-validación-en-instana)
12. [Diagnóstico](#12-diagnóstico)
13. [Rollback](#13-rollback)
14. [Checklist de implementación](#14-checklist-de-implementación)

---

## 1. Documentación de referencia

- [IBM Instana: Monitoring SAP with the ABAP sensor](https://www.ibm.com/docs/en/instana-observability?topic=sap-monitoring-abap-sensor)
- [SAP Java Connector](https://support.sap.com/en/product/connectors/jco.html)
- [IBM Instana: Configuring host agents by using the agent configuration file](https://www.ibm.com/docs/en/instana-observability?topic=cha-configuring-host-agents-by-using-agent-configuration-file)

SAP JCo debe descargarse desde el portal oficial de SAP. No se recomienda obtener la librería desde GitHub, Maven u otros repositorios no oficiales.

---

## 2. Arquitectura de conexión

El sensor SAP ABAP puede conectarse mediante alguno de los siguientes esquemas:

| Modalidad | Uso |
|---|---|
| Local | El agente Instana se ejecuta en el mismo servidor que la instancia ABAP. |
| Remota directa | El agente Instana se ejecuta en otro servidor y se conecta directamente al Application Server ABAP. |
| SAP Message Server | El agente se conecta mediante el Message Server y un grupo de logon. |
| SAProuter | Se utiliza cuando la comunicación debe pasar por un SAProuter. |

> [!WARNING]
> Configure las instancias ABAP mediante conexión directa o mediante SAP Message Server. No mezcle ambos métodos dentro de la misma configuración del sensor.

---

## 3. Prerrequisitos

Antes de iniciar, verifique lo siguiente:

- Agente de host Instana instalado y operativo.
- Acceso administrativo al servidor del agente.
- SAP JCo 3.1.8 o superior descargado para el sistema operativo y la arquitectura donde se ejecuta el agente Instana.
- Usuario técnico creado en SAP ABAP.
- Autorizaciones SAP requeridas asignadas al usuario técnico.
- Conectividad de red entre el agente y SAP, cuando la conexión sea remota.
- Número de instancia ABAP (`sysnr`) y mandante SAP (`client`) confirmados.
- Respaldo del archivo de configuración del agente.

> [!NOTE]
> SAP JCo debe corresponder a la plataforma del **servidor donde se ejecuta el agente Instana**, no necesariamente a la plataforma del servidor SAP monitoreado.

---

## 4. Información requerida

Antes de modificar la configuración, recopile la siguiente información:

| Variable | Descripción | Ejemplo | Cómo obtenerla |
|---|---|---:|---|
| `SID` | Identificador del sistema SAP | `EEQ` | Directorio `/usr/sap`, perfiles SAP o equipo SAP Basis |
| `sysnr` | Número de la instancia Application Server ABAP | `00` | Instancia `D00`, procesos SAP, perfiles o `sapcontrol` |
| `client` | Mandante SAP de tres dígitos | `200` | SAP GUI, transacción `SCC4`, tabla `T000` o SAP Basis |
| `host` | FQDN o IP de la instancia SAP | `sap-app.example.com` | DNS o SAP Basis |
| `user` | Usuario técnico SAP | `INSTANA_MON` | SAP Basis o Seguridad SAP |
| `password` | Contraseña del usuario técnico | — | Entrega segura por SAP Basis |
| `lang` | Idioma de conexión SAP | `en` | Definido con SAP Basis; el valor predeterminado es `en` |
| `pool_capacity` | Máximo de conexiones del sensor | `10` | Valor inicial recomendado en el ejemplo oficial |
| `poll_rate` | Intervalo de consulta, en segundos | `60` | Valor predeterminado del sensor |
| `libpath` | Ruta de SAP JCo en el agente | `/opt/instana/agent/system/com/sap/sapjco3/3.1.13/` | Se crea durante este procedimiento |
| `port` | Puerto del SAP Message Server | `3601` | Normalmente `36NN`, donde `NN` es la instancia ASCS |
| `group` | Grupo de logon SAP | `PUBLIC` | SAP Basis; `PUBLIC` es el valor predeterminado |
| `sap_router` | Cadena de conexión SAProuter | `/H/router.example.com` | SAP Basis o equipo de redes SAP |

### 4.1 Diferencia entre `sysnr` y `client`

- `sysnr` identifica la instancia técnica ABAP y siempre tiene dos dígitos. Por ejemplo, una instancia `D00` utiliza `sysnr: '00'`.
- `client` identifica el mandante lógico SAP y tiene tres dígitos, por ejemplo `100`, `200` o `300`.

El número de `ASCS01` no debe utilizarse como `sysnr` cuando la conexión directa se realiza hacia la instancia ABAP `D00`.

---

## 5. Validaciones previas

### 5.1 Validar el agente Instana

```bash
sudo systemctl status instana-agent.service --no-pager --full
```

Confirmar que existe el archivo de configuración:

```bash
sudo test -f /opt/instana/agent/etc/instana/configuration.yaml \
  && echo "OK: configuración del agente encontrada" \
  || echo "ERROR: no se encontró configuration.yaml"
```

Validar la ruta principal:

```bash
sudo ls -ld /opt/instana/agent
sudo ls -l /opt/instana/agent/etc/instana/
```

### 5.2 Confirmar que el servidor ejecuta SAP ABAP

Buscar los procesos principales:

```bash
ps -ef | grep -E 'disp\+work|dw\.sap|gwrd|icman|ms\.sap|en\.sap|sapstartsrv' | grep -v grep
```

Los procesos `disp+work` o `dw.sap<SID>_D<NN>` identifican una instancia Application Server ABAP.

Buscar las instancias instaladas:

```bash
sudo find /usr/sap -maxdepth 3 -type d \
  \( -name 'D[0-9][0-9]' -o -name 'DVEBMGS[0-9][0-9]' -o -name 'ASCS[0-9][0-9]' \) \
  2>/dev/null
```

Obtener rápidamente el SID y número de instancia desde los procesos:

```bash
ps -ef \
  | sed -nE 's/.*dw\.sap([A-Za-z0-9]{3})_D([0-9]{2}).*/SID=\1 SYSNR=\2/p' \
  | sort -u
```

Ejemplo de resultado:

```text
SID=EEQ SYSNR=00
```

### 5.3 Validar con `sapcontrol`

Reemplace `00` por el número de la instancia ABAP:

```bash
sudo /usr/sap/hostctrl/exe/sapcontrol -nr 00 -function GetProcessList
```

Consultar las instancias del sistema:

```bash
sudo /usr/sap/hostctrl/exe/sapcontrol -nr 00 -function GetSystemInstanceList
```

Consultar la versión:

```bash
sudo /usr/sap/hostctrl/exe/sapcontrol -nr 00 -function GetVersionInfo
```

### 5.4 Obtener el `sysnr`

Buscar instancias `DNN`:

```bash
sudo find /usr/sap -maxdepth 3 -type d -name 'D[0-9][0-9]' 2>/dev/null
```

Revisar procesos:

```bash
ps -ef | grep -E 'dw\.sap|disp\+work' | grep -v grep
```

Revisar perfiles SAP:

```bash
sudo grep -RHE '^[[:space:]]*SAPSYSTEM[[:space:]]*=' \
  /usr/sap/*/SYS/profile/ 2>/dev/null
```

Ejemplo:

```text
/usr/sap/EEQ/D00
```

Resultado:

```yaml
sysnr: '00'
```

### 5.5 Obtener el `client`

El `client` no se obtiene a partir del nombre de la instancia Linux. Debe confirmarse dentro del sistema SAP:

- Campo **Mandante / Client** en SAP GUI.
- Menú **Sistema > Status**.
- Transacción `SCC4`.
- Consulta de la tabla `T000` mediante `SE16N`.
- Confirmación del equipo SAP Basis.

Utilice el mismo mandante donde se creó el usuario técnico de Instana.

### 5.6 Validar sistema operativo, arquitectura y JVM

```bash
uname -s
uname -m
getconf LONG_BIT
```

Ejemplos:

| Resultado | Paquete SAP JCo |
|---|---|
| `x86_64` | Linux 64-bit x86 |
| `aarch64` | Linux 64-bit ARM |
| `ppc64le` | Linux PowerPC 64-bit Little Endian |
| `s390x` | Linux zSeries 64-bit |

Validar la JVM incluida con el agente:

```bash
/opt/instana/agent/jvm/bin/java -version
```

Validar su arquitectura:

```bash
file "$(readlink -f /opt/instana/agent/jvm/bin/java)"
```

> [!IMPORTANT]
> Una JVM de 64 bits requiere la variante de SAP JCo de 64 bits para la plataforma correspondiente.

### 5.7 Buscar una instalación existente de SAP JCo

Búsqueda completa:

```bash
sudo find / -type f \
  \( -iname 'sapjco3*.jar' -o -iname 'libsapjco3.so' -o -iname 'sapjco3.dll' \) \
  2>/dev/null
```

Búsqueda limitada a rutas comunes:

```bash
sudo find /usr/sap /sapmnt /opt /home -type f \
  \( -iname 'sapjco3*.jar' -o -iname 'libsapjco3.so' -o -iname 'sapjco3.dll' \) \
  2>/dev/null
```

Validar la versión de un JAR existente:

```bash
unzip -p /ruta/sapjco3.jar META-INF/MANIFEST.MF \
  | grep -iE 'Implementation-Version|Specification-Version|Bundle-Version'
```

---

## 6. Descarga de SAP JCo

Descargue SAP JCo desde el portal oficial:

**[Descargar SAP Java Connector](https://support.sap.com/en/product/connectors/jco.html)**

Seleccione el SDK correspondiente al sistema operativo y arquitectura del servidor donde se ejecuta el agente Instana.

Para Linux, el paquete incluye principalmente:

```text
sapjco3.jar
libsapjco3.so
```

Para Windows:

```text
sapjco3.jar
sapjco3.dll
```

SAP distribuye algunos paquetes Unix como un archivo `.tgz` incluido dentro de un `.zip`. Primero extraiga el archivo externo y luego el paquete específico de la plataforma.

> [!WARNING]
> No extraiga todo el SDK directamente dentro del directorio del agente. Para el sensor solo se requieren:
>
> - `sapjco3.jar`
> - Una librería nativa para el sistema operativo: `libsapjco3.so` o `sapjco3.dll`

---

## 7. Instalación de SAP JCo

Los siguientes pasos utilizan SAP JCo `3.1.13` como ejemplo.

### 7.1 Definir las variables

Ejecute este bloque directamente en la consola:

```bash
INSTANA_HOME="/opt/instana/agent"
JCO_VERSION="3.1.13"
JCO_SOURCE="/tmp/sapjco3"
JCO_TARGET="${INSTANA_HOME}/system/com/sap/sapjco3/${JCO_VERSION}"
```

Ajuste `JCO_SOURCE` a la ruta donde fueron extraídos los dos archivos requeridos.

Verifique las variables:

```bash
printf 'INSTANA_HOME=%s\nJCO_VERSION=%s\nJCO_SOURCE=%s\nJCO_TARGET=%s\n' \
  "${INSTANA_HOME}" "${JCO_VERSION}" "${JCO_SOURCE}" "${JCO_TARGET}"
```

### 7.2 Verificar los archivos de origen

```bash
sudo find "${JCO_SOURCE}" -maxdepth 2 -type f \
  \( -name 'sapjco3.jar' -o -name 'libsapjco3.so' -o -name 'sapjco3.dll' \) \
  -print
```

En Linux deben encontrarse:

```text
sapjco3.jar
libsapjco3.so
```

### 7.3 Crear la ruta de destino

```bash
sudo install -d -m 0755 "${JCO_TARGET}"
```

La ruta resultante será:

```text
/opt/instana/agent/system/com/sap/sapjco3/3.1.13
```

### 7.4 Copiar SAP JCo en Linux

Copiar y renombrar el JAR:

```bash
sudo install -m 0644 \
  "${JCO_SOURCE}/sapjco3.jar" \
  "${JCO_TARGET}/sapjco3-${JCO_VERSION}.jar"
```

Copiar la librería nativa sin renombrarla:

```bash
sudo install -m 0755 \
  "${JCO_SOURCE}/libsapjco3.so" \
  "${JCO_TARGET}/libsapjco3.so"
```

> [!IMPORTANT]
> No renombre `libsapjco3.so` ni `sapjco3.dll`.

### 7.5 Verificar el contenido

```bash
sudo ls -lah "${JCO_TARGET}"
```

Resultado esperado en Linux:

```text
libsapjco3.so
sapjco3-3.1.13.jar
```

Confirmar que exista un solo JAR:

```bash
JAR_COUNT="$(find "${JCO_TARGET}" -maxdepth 1 -type f -name '*.jar' | wc -l)"

if [ "${JAR_COUNT}" -eq 1 ]; then
  echo "OK: se encontró un único archivo JAR"
else
  echo "ERROR: se encontraron ${JAR_COUNT} archivos JAR"
fi
```

Validar la arquitectura de la librería:

```bash
file "${JCO_TARGET}/libsapjco3.so"
```

Validar dependencias nativas:

```bash
ldd "${JCO_TARGET}/libsapjco3.so"
```

El resultado no debe contener dependencias con estado `not found`:

```bash
ldd "${JCO_TARGET}/libsapjco3.so" | grep 'not found' \
  && echo "ERROR: existen dependencias faltantes" \
  || echo "OK: no se detectaron dependencias faltantes"
```

### 7.6 Validar la versión del JAR instalado

```bash
unzip -p "${JCO_TARGET}/sapjco3-${JCO_VERSION}.jar" META-INF/MANIFEST.MF \
  | grep -iE 'Implementation-Version|Specification-Version|Bundle-Version'
```

---

## 8. Autorizaciones del usuario SAP

El usuario configurado en el sensor debe tener autorización para obtener métricas en el mismo `client` e instancia definidos en el YAML.

Objetos requeridos:

```text
Authorization Object: S_RFC
    RFC_TYPE: Function Module
    RFC_NAME: *
    Activity: Execute

Authorization Object: /SDF/E2E
    Activity: 03

Authorization Object: S_ADMI_FCD
    S_ADMI_FCD: ST0R

Authorization Object: S_RZL_ADM
    Activity: 03

Authorization Object: S_TABU_DIS
    DICBERCLS: &NC&,EDI0,SA,SC,SS,SPWD
    Activity: 03
```

La creación del usuario y asignación de autorizaciones debe realizarse por el equipo SAP Basis o Seguridad SAP.

---

## 9. Configuración del sensor

### 9.1 Respaldar la configuración actual

```bash
sudo cp -a \
  /opt/instana/agent/etc/instana/configuration.yaml \
  "/opt/instana/agent/etc/instana/configuration.yaml.bak.$(date +%Y%m%d-%H%M%S)"
```

Listar los respaldos:

```bash
sudo ls -lt /opt/instana/agent/etc/instana/configuration.yaml.bak.* 2>/dev/null
```

### 9.2 Usar un archivo modular

Se recomienda crear un archivo separado:

```text
/opt/instana/agent/etc/instana/configuration-sap-abap.yaml
```

Los archivos `configuration-<suffix>.yaml` se combinan con `configuration.yaml`, lo que facilita el mantenimiento y rollback.

Crear o editar el archivo:

```bash
sudo vi /opt/instana/agent/etc/instana/configuration-sap-abap.yaml
```

También puede utilizarse el archivo principal:

```bash
sudo vi /opt/instana/agent/etc/instana/configuration.yaml
```

![Configuración del sensor SAP ABAP en configuration.yaml](https://github.com/user-attachments/assets/e34b0db7-3cda-424e-b250-4990e2d70743)

> [!IMPORTANT]
> YAML es sensible a la indentación. Utilice espacios y no tabulaciones.

### 9.3 Configuración local

Utilice esta opción cuando el agente Instana se encuentra en el mismo servidor que la instancia ABAP.

```yaml
# SAP ABAP - conexión local
com.instana.plugin.sap.abap:
  local:
    - sysnr: '00'
      client: '200'
      user: 'INSTANA_MON'
      password: '<PASSWORD>'
      lang: 'en'
      pool_capacity: '10'
      libpath: '/opt/instana/agent/system/com/sap/sapjco3/3.1.13/'
      poll_rate: 60
```

No agregue `host` en una conexión local.

### 9.4 Configuración remota directa

Utilice esta opción cuando el agente se encuentra en otro servidor y se conecta al Application Server ABAP.

```yaml
# SAP ABAP - conexión remota directa
com.instana.plugin.sap.abap:
  remote:
    - host: 'sap-app.example.com'
      sysnr: '00'
      client: '200'
      user: 'INSTANA_MON'
      password: '<PASSWORD>'
      lang: 'en'
      pool_capacity: '10'
      libpath: '/opt/instana/agent/system/com/sap/sapjco3/3.1.13/'
      poll_rate: 60
```

### 9.5 Configuración de varias instancias remotas

```yaml
# SAP ABAP - múltiples instancias remotas directas
com.instana.plugin.sap.abap:
  remote:
    - host: 'sap-app-01.example.com'
      sysnr: '00'
      client: '200'
      user: 'INSTANA_MON'
      password: '<PASSWORD>'
      lang: 'en'
      pool_capacity: '10'
      libpath: '/opt/instana/agent/system/com/sap/sapjco3/3.1.13/'
      poll_rate: 60

    - host: 'sap-app-02.example.com'
      sysnr: '01'
      client: '200'
      user: 'INSTANA_MON'
      password: '<PASSWORD>'
      lang: 'en'
      pool_capacity: '10'
      libpath: '/opt/instana/agent/system/com/sap/sapjco3/3.1.13/'
      poll_rate: 60
```

### 9.6 Configuración mediante SAP Message Server

```yaml
# SAP ABAP - conexión mediante SAP Message Server
com.instana.plugin.sap.abap:
  remote:
    - host: 'sap-message-server.example.com'
      port: '3601'
      type: 'message_server'
      client: '200'
      user: 'INSTANA_MON'
      password: '<PASSWORD>'
      group: 'PUBLIC'
      lang: 'en'
      pool_capacity: '10'
      libpath: '/opt/instana/agent/system/com/sap/sapjco3/3.1.13/'
      poll_rate: 60
```

El puerto del Message Server normalmente sigue el formato:

```text
36NN
```

Donde `NN` es el número de la instancia ASCS.

Ejemplo:

```text
ASCS01 → 3601
```

Confirme siempre el puerto con SAP Basis porque puede haber sido personalizado.

### 9.7 Configuración mediante SAProuter

Agregue `sap_router` dentro de la conexión correspondiente.

Puerto predeterminado `3299`:

```yaml
sap_router: '/H/saprouter.example.com'
```

Puerto personalizado:

```yaml
sap_router: '/H/saprouter.example.com/P/3298'
```

Ejemplo completo con conexión remota:

```yaml
# SAP ABAP - conexión remota mediante SAProuter
com.instana.plugin.sap.abap:
  remote:
    - host: 'sap-app.example.com'
      sysnr: '00'
      client: '200'
      user: 'INSTANA_MON'
      password: '<PASSWORD>'
      sap_router: '/H/saprouter.example.com'
      lang: 'en'
      pool_capacity: '10'
      libpath: '/opt/instana/agent/system/com/sap/sapjco3/3.1.13/'
      poll_rate: 60
```

### 9.8 Proteger la contraseña mediante un archivo local

Para evitar colocar la contraseña directamente en el YAML, cree un archivo protegido.

Crear el directorio:

```bash
sudo install -d -m 0700 /opt/instana/agent/etc/instana/secrets
```

Capturar la contraseña sin mostrarla en la consola:

```bash
read -rsp "Password del usuario SAP: " SAP_PASSWORD
echo
printf '%s' "${SAP_PASSWORD}" \
  | sudo tee /opt/instana/agent/etc/instana/secrets/sap-abap.password \
  >/dev/null
unset SAP_PASSWORD
```

Aplicar permisos:

```bash
sudo chmod 600 /opt/instana/agent/etc/instana/secrets/sap-abap.password
```

Reemplazar `password: '<PASSWORD>'` por:

```yaml
password:
  configuration_from:
    type: agent_file
    file_path: '/opt/instana/agent/etc/instana/secrets/sap-abap.password'
```

Ejemplo local:

```yaml
# SAP ABAP - conexión local con contraseña en archivo protegido
com.instana.plugin.sap.abap:
  local:
    - sysnr: '00'
      client: '200'
      user: 'INSTANA_MON'
      password:
        configuration_from:
          type: agent_file
          file_path: '/opt/instana/agent/etc/instana/secrets/sap-abap.password'
      lang: 'en'
      pool_capacity: '10'
      libpath: '/opt/instana/agent/system/com/sap/sapjco3/3.1.13/'
      poll_rate: 60
```

### 9.9 Validar el YAML

Verificar que no existan tabulaciones:

```bash
sudo grep -n $'\t' \
  /opt/instana/agent/etc/instana/configuration-sap-abap.yaml
```

Si el comando no devuelve resultados, no se detectaron tabulaciones.

Cuando `yamllint` esté disponible:

```bash
sudo yamllint /opt/instana/agent/etc/instana/configuration-sap-abap.yaml
```

Revisar el bloque configurado:

```bash
sudo sed -n '/com\.instana\.plugin\.sap\.abap:/,$p' \
  /opt/instana/agent/etc/instana/configuration-sap-abap.yaml
```

---

## 10. Aplicación de la configuración

### 10.1 Validar conectividad remota directa

Definir las variables:

```bash
SAP_HOST="sap-app.example.com"
SYSNR="00"
```

Validar resolución DNS:

```bash
getent hosts "${SAP_HOST}"
```

Validar el puerto SAP Gateway:

```bash
nc -vz "${SAP_HOST}" "33${SYSNR}"
```

Para `D00`, normalmente se valida:

```bash
nc -vz sap-app.example.com 3300
```

### 10.2 Validar conectividad al Message Server

```bash
MESSAGE_SERVER="sap-message-server.example.com"
ASCS_NR="01"
```

Validar DNS:

```bash
getent hosts "${MESSAGE_SERVER}"
```

Validar puerto:

```bash
nc -vz "${MESSAGE_SERVER}" "36${ASCS_NR}"
```

Para `ASCS01`, normalmente:

```bash
nc -vz sap-message-server.example.com 3601
```

### 10.3 Confirmar puertos en el servidor SAP

```bash
sudo ss -lntp | grep -E ':(33[0-9]{2}|36[0-9]{2})\b'
```

### 10.4 Reiniciar únicamente el agente Instana

```bash
sudo systemctl restart instana-agent.service
```

No es necesario reiniciar la instancia SAP ABAP, ASCS ni otros servicios SAP.

### 10.5 Validar el estado del agente

```bash
sudo systemctl status instana-agent.service --no-pager --full
```

---

## 11. Validación en Instana

Después de aplicar la configuración, ingrese a la interfaz de Instana.

### 11.1 Ubicar la plataforma SAP

En el menú principal:

```text
Platform > SAP
```

![Vista Platform SAP en Instana](https://github.com/user-attachments/assets/324600be-01b2-4963-b428-e980446b6569)

### 11.2 Ubicar la instancia SAP

Seleccione la pestaña **Instances**.

El nombre del sensor se presenta con un formato similar a:

```text
AbapInstance@HostName_SID_InstanceID
```

Ejemplo:

```text
AbapInstance@sapserver_EEQ_00
```

![Listado de instancias SAP en Instana](https://github.com/user-attachments/assets/03982454-8d06-4431-aa86-eeb008c7aacd)

### 11.3 Revisar las métricas

Abra la instancia para validar la recepción de métricas de CPU, memoria, work processes, jobs, conexiones, errores, dumps, RFC, ICM, Gateway y otros componentes SAP.

![Detalle de la instancia SAP ABAP](https://github.com/user-attachments/assets/97868337-5288-4692-855f-25a88570f63b)

También puede revisar:

```text
Infrastructure > Map > SAP tower > Open Dashboard
```

---

## 12. Diagnóstico

### 12.1 Revisar logs recientes del servicio

```bash
sudo journalctl \
  -u instana-agent.service \
  --since "15 minutes ago" \
  --no-pager \
  | grep -iE 'sap|abap|jco|rfc|error|exception|failed'
```

### 12.2 Revisar el log del agente

```bash
sudo grep -iE 'sap|abap|jco|rfc|error|exception|failed' \
  /opt/instana/agent/data/log/agent.log \
  2>/dev/null \
  | tail -200
```

Seguimiento en tiempo real:

```bash
sudo tail -f /opt/instana/agent/data/log/agent.log \
  | grep --line-buffered -iE 'sap|abap|jco|rfc|error|exception|failed'
```

### 12.3 Verificar archivos SAP JCo

```bash
sudo find /opt/instana/agent/system/com/sap/sapjco3 \
  -maxdepth 2 -type f \
  \( -name '*.jar' -o -name '*.so' -o -name '*.dll' \) \
  -print
```

### 12.4 Problemas frecuentes

| Mensaje o síntoma | Validación |
|---|---|
| `JCo library not found` | Verificar `libpath`, nombre del JAR y existencia de la librería nativa |
| `UnsatisfiedLinkError` | Validar arquitectura, permisos y dependencias con `file` y `ldd` |
| `Name or password is incorrect` | Confirmar usuario, contraseña y mandante |
| `partner not reached` | Revisar DNS, host, `sysnr`, puertos y firewall |
| `authorization failure` | Revisar objetos y actividades asignados al usuario SAP |
| La instancia no aparece en Instana | Revisar YAML, logs del agente y reiniciar el servicio |
| Se detectan varios JAR | Dejar un único archivo `.jar` en el directorio de la versión |
| `libsapjco3.so: not found` | Confirmar que el archivo está en `libpath` y que la arquitectura sea compatible |
| Error de Message Server | Confirmar host, puerto `36NN`, grupo de logon y conectividad |

### 12.5 Validación rápida consolidada

```bash
JCO_VERSION="3.1.13"
JCO_DIR="/opt/instana/agent/system/com/sap/sapjco3/${JCO_VERSION}"

echo "=== Servicio Instana ==="
sudo systemctl is-active instana-agent.service

echo
echo "=== Archivos SAP JCo ==="
sudo ls -lah "${JCO_DIR}"

echo
echo "=== Arquitectura de la librería ==="
file "${JCO_DIR}/libsapjco3.so"

echo
echo "=== Dependencias faltantes ==="
ldd "${JCO_DIR}/libsapjco3.so" | grep 'not found' || echo "OK"

echo
echo "=== Configuración SAP ABAP ==="
sudo grep -Rni 'com\.instana\.plugin\.sap\.abap' \
  /opt/instana/agent/etc/instana/configuration*.yaml

echo
echo "=== Logs recientes ==="
sudo journalctl -u instana-agent.service --since "10 minutes ago" --no-pager \
  | grep -iE 'sap|abap|jco|rfc|error|exception|failed' \
  | tail -100
```

---

## 13. Rollback

Cuando se utiliza un archivo modular, deshabilite únicamente la configuración SAP ABAP:

```bash
sudo mv \
  /opt/instana/agent/etc/instana/configuration-sap-abap.yaml \
  /opt/instana/agent/etc/instana/configuration-sap-abap.yaml.disabled
```

Reinicie el agente:

```bash
sudo systemctl restart instana-agent.service
```

Validar:

```bash
sudo systemctl status instana-agent.service --no-pager --full
```

Para restaurar el archivo:

```bash
sudo mv \
  /opt/instana/agent/etc/instana/configuration-sap-abap.yaml.disabled \
  /opt/instana/agent/etc/instana/configuration-sap-abap.yaml
```

Luego reinicie nuevamente el agente:

```bash
sudo systemctl restart instana-agent.service
```

Si se modificó directamente `configuration.yaml`, restaure el respaldo correspondiente:

```bash
sudo cp -a \
  /opt/instana/agent/etc/instana/configuration.yaml.bak.<FECHA-HORA> \
  /opt/instana/agent/etc/instana/configuration.yaml
```

---

## 14. Checklist de implementación

### Datos SAP

- [ ] SID confirmado.
- [ ] Instancia ABAP y `sysnr` confirmados.
- [ ] Mandante `client` confirmado.
- [ ] Usuario técnico creado en el mandante correcto.
- [ ] Autorizaciones SAP asignadas.
- [ ] Contraseña entregada mediante un canal seguro.

### Agente y SAP JCo

- [ ] Agente Instana activo.
- [ ] SO, arquitectura y JVM validados.
- [ ] SAP JCo 3.1.8 o superior descargado desde SAP.
- [ ] Paquete seleccionado para la plataforma del agente.
- [ ] Ruta `system/com/sap/sapjco3/<versión>` creada.
- [ ] JAR copiado y renombrado con la versión.
- [ ] Librería `.so` o `.dll` copiada sin renombrar.
- [ ] Existe un único archivo JAR en la ruta.
- [ ] No existen dependencias nativas faltantes.

### Configuración y validación

- [ ] Método de conexión definido: local, remoto, Message Server o SAProuter.
- [ ] `libpath` apunta a la versión instalada.
- [ ] YAML validado sin tabulaciones.
- [ ] Conectividad a los puertos SAP confirmada.
- [ ] Agente Instana reiniciado.
- [ ] Logs revisados sin errores SAP JCo o RFC.
- [ ] Sistema e instancia visibles en `Platform > SAP`.
- [ ] Métricas SAP validadas.
- [ ] Procedimiento de rollback documentado.

---

## Referencias

- [IBM Instana — Monitoring SAP with the ABAP sensor](https://www.ibm.com/docs/en/instana-observability?topic=sap-monitoring-abap-sensor)
- [SAP — SAP Java Connector](https://support.sap.com/en/product/connectors/jco.html)
- [IBM Instana — Configuring host agents by using the agent configuration file](https://www.ibm.com/docs/en/instana-observability?topic=cha-configuring-host-agents-by-using-agent-configuration-file)

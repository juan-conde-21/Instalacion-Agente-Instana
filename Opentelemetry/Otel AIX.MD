# Guía de Instalación y Configuración de OpenTelemetry Collector en IBM AIX

Esta guía detalla el proceso paso a paso para descargar, instalar, configurar y registrar **OpenTelemetry Collector** como un servicio en el sistema operativo IBM AIX utilizando el paquete oficial de IBM AIX Toolbox.

---

## 1. Descarga del paquete OpenTelemetry

Accede al sitio de [IBM AIX Toolbox Open Source Software](https://www.ibm.com/support/pages/aix-toolbox-open-source-software-downloads-alpha#O) y localiza la sección correspondiente a **otelcol-contrib**.

* Elige la versión del paquete RPM que coincida exactamente con la versión de tu sistema operativo AIX (por ejemplo, AIX 7.2 o AIX 7.3):

![Selección de versión de AIX](image_3eca51.png)

* **Verificación:** Descarga el archivo correspondiente (por ejemplo, `otelcol-contrib-0.152.0-2.aix7.2.ppc.rpm`) listo para ser transferido al servidor.

---

## 2. Transferencia e Instalación en el Servidor AIX

Sube el archivo RPM descargado al servidor AIX utilizando una herramienta de transferencia segura (como SFTP o SCP). Una vez en el servidor, ejecuta el siguiente comando con privilegios de administrador para realizar la instalación:

```bash
rpm -ivh otelcol-contrib-0.152.0-2.aix7.2.ppc.rpm
```

* **Verificación:** Asegúrate de que el comando finalice correctamente sin errores de dependencias o conflictos de paquetes.

---

## 3. Verificación de la Ruta de Instalación

Confirma que el binario principal del colector se encuentre correctamente ubicado en la ruta estándar del entorno liberado de AIX:

```bash
ls -l /opt/freeware/bin/otelcol-contrib
```

* **Verificación:** El archivo debe existir y contar con los permisos de ejecución adecuados.

---

## 4. Creación del Archivo de Configuración

Crea el directorio de configuración predeterminado si este no existe y procede a crear el archivo `config.yaml`:

```bash
mkdir -p /etc/otelcol
vi /etc/otelcol/config.yaml
```

Añade las configuraciones típicas estructuradas en receptores (`receivers`), procesadores (`processors`), exportadores (`exporters`) y pipelines de servicios (`service`):

```yaml
receivers:
  otlp:
    protocols:
      grpc:
      http:

processors:
  batch:

exporters:
  logging:
    verbosity: detailed

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [logging]
    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [logging]
```

---

## 5. Validación Inicial de Ejecución

Antes de registrarlo como servicio permanente, prueba la ejecución exitosa del colector en primer plano pasando el archivo de configuración creado:

```bash
/opt/freeware/bin/otelcol-contrib --config /etc/otelcol/config.yaml
```

* **Verificación:** Observa la salida por consola para confirmar que los componentes se inicializan correctamente. Presiona `Ctrl + C` para detener la ejecución una vez validado.

---

## 6. Configuración y Gestión como Servicio de AIX (SRC)

Para registrar OpenTelemetry como un subsistema gestionado por el Controlador de Recursos del Sistema (SRC) de AIX, ejecuta el comando `mkssys`:

```bash
mkssys -s otelcol -p /opt/freeware/bin/otelcol-contrib -a "--config /etc/otelcol/config.yaml" -u root -S -n 15 -f 9
```

Una vez creado el subsistema, arranca el servicio y valida su estado operativo con los siguientes comandos:

```bash
# Arrancar el servicio
startsrc -s otelcol

# Validar el estado del servicio
lssrc -s otelcol
```

* **Verificación final:** El comando `lssrc` debe reportar que el subsistema `otelcol` se encuentra en estado `active` asociado al proceso en ejecución.

# Recolección de Logs Utilizando el Filelog Receiver de Opentelemetry

## Prerequisitos

1. Agente Instana desplegado. (Windows/Linux)
2. Sensor de Opentelemetry habilitado en el Agente Instana.

## Desplegar Colector de Opentelemetry Contrib

1. Descargar el instalador del Colector de Opentelemetry Contrib desde la pagina oficial de Opentelemetry.(https://github.com/open-telemetry/opentelemetry-collector-releases/releases)

2. Seleccionar la versión correspondiente a la arquitectura y version de Sistema Operativo donde se instalara el colector de Opentelemetry.

    Para este ejemplo se desplegara en el sistema operativo Ubuntu 22.04 x86:

    ![image](https://github.com/user-attachments/assets/39a50bba-a12d-4dcd-af2d-3e89ce5ca24e)

3. Instalar el paquete descargado a nivel de Sistema Operativo.

    Ejecutar el siguiente comando(Ubuntu):

       dpkg -i otelcol-contrib_0.110.0_linux_amd64.deb

    Ejecutar el siguiente comando(RedHat/CentOS):

       rpm -ivh otelcol-contrib_0.110.0_linux_amd64.rpm

    Ejemplo de ejecución:
   

4. Ingresar al archivo de configuración del colector Opentelemetry y agregar la configuracion de la ruta de los logs a monitorear.

    Ejecutar el siguiente comando:

       cd /etc/otelcol-contrib/

    Editar el archivo de configuración del Colector:

       vi config.yaml

      Agregar el siguiente contenido y modificar la ruta de los logs que seran leidos en la seccion include:

       receivers:
         filelog:
           ## Ruta de los logs que seran leidos, puede ser ruta absoluta o utilizando wildcard
           include: [ "/var/log/apache2/*.log" ]
       
       processors:
         batch:
       
       exporters:
         otlp:
           endpoint: "localhost:4317"
           tls:
             insecure: true
         debug:
           verbosity: detailed
       
       service:
       
         pipelines:
       
           logs:
             receivers: [filelog]
             processors: [batch]
             exporters: [otlp]






## Plataforma Linux
1. Ingresar al archivo de configuración del agente Instana

   Windows

       C:\Program Files\Instana\instana-agent\etc\instana

   Linux / Unix

       /opt/instana/agent/etc/instana/




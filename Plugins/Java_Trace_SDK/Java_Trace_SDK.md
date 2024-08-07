# Habilitación de Plugin Java Trace SDK

1. Ingresar al archivo de configuración del agente Instana

   Windows

       C:\Program Files\Instana\instana-agent\etc\instana\configuration.yaml

   Linux

       /opt/instana/agent/etc/instana/configuration.yaml

2. Ubicar las lineas para el plugin de Java Trace SDK en el archivo de configuracion.

   ![image](https://github.com/user-attachments/assets/95b81b13-559a-4e50-86d7-925f70a0ed6d)

3. Proceder a modificar colocando el nombre del paquete donde se realizó la instrumentación con el sdk para java de Instana y guardar los cambios. Para este ejemplo se utiliza el paquete "com.example.hello_spring"

   Lineas de configuracion:

       # Java Tracing
       com.instana.plugin.javatrace:
         instrumentation:
           sdk:
             packages:
               - 'com.example.hello_spring'
       #    # Lightweight Bytecode Instrumentation, enabled by default
       #    # Disabling currently requires an agent restart
           enabled: true

4. Reiniciar el agente Instana desde linea de comandos.

   Windows

       net stop "instana-agent-service"
       net start "instana-agent-service"

   Linux

       systemctl stop instana-agent
       systemctl start instana-agent







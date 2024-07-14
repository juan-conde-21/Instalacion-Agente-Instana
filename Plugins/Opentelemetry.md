# Habilitación de Opentelemetry en Agente Instana


## Plataforma Windows, Linux , UNIX
1. Ingresar al archivo de configuración del agente Instana

   Windows

       C:\Program Files\Instana\instana-agent\etc\instana

   Linux / Unix

       /opt/instana/agent/etc/instana/

2. Ubicar las lineas para el plugin de Opentelemetry en el archivo configuracion.yaml.

       configuration.yaml

3. Descomentar las lineas del plugin Opentelemetry y realizar las modificaciones de acuerdo con el ambiente a configurar.

       com.instana.plugin.opentelemetry:
         grpc:
           enabled: true
         http:
           enabled: true

4. Reiniciar el agente Instana.

   Windows: Abrir ventana de linea de comandos y ejecutar los siguiente comandos.

       net stop instana-agent-service
       net start instana-agent-service

     Ejemplo de ejecucion:
  
     ![image](https://github.com/user-attachments/assets/0f090093-e0a9-4e7e-beda-27ca7569e87f)


   Linux: Ejecutar los siguientes comandos.

       systemctl stop instana-agent
       systemctl start instana-agent

     Ejemplo de ejecucion:

     

   Unix

       cd  /opt/instana-agent/bin/
       ./stop
       ./start
       ./status
     

     Ejemplo de ejecucion:

     ![image](https://github.com/user-attachments/assets/37abf03b-f491-4ead-8287-3394bf337872)


   

## Plataforma Kubernetes




## Plataforma Openshift

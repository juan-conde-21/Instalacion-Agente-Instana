# Habilitación de Plugin IBM iSeries

1. Ingresar al archivo de configuración del agente Instana

   Windows

       C:\Program Files\Instana\instana-agent\etc\instana

   Linux

       /opt/instana/agent/etc/instana/

2. Ubicar las lineas para el plugin de IBM iSeries en el archivo de configuracion.

       vi configuration.yaml

       ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/935b5ea0-b534-41f0-9006-bb21ae967059)

   Configuración de ejemplo:

       # IBM i Series
       com.instana.plugin.ibmiseries:
         enabled: true
         remote: # multiple configurations supported
           - host: 'remote.host-1.com'
              #For a SSL connection set sslEnabled to either true or false.
       #      sslEnabled: 'true/false'
             user: 'username'
             password: 'password'
             availabilityZone: 'IBM i Remote Monitoring'
             poll_rate: 15 # seconds


3. Guardar los cambios y verificar que el servidor iSeries se encuentre reportando en Instana.

   En el módulo de infraestructura:

   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/8d369920-ef78-4200-b49d-a58384d5c768)

   Filtrar por Sistema operativo: entity.selfType:ibmi.os

   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/717d752c-5129-42bf-9731-5038f0795337)





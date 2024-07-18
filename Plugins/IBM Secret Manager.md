# Habilitación de Plugin IBM Secret Manager

1. Ingresar al archivo de configuración del agente Instana

   Windows

       C:\Program Files\Instana\instana-agent\etc\instana

   Linux

       /opt/instana/agent/etc/instana/

2. Ubicar las lineas para el plugin de IBM Secret Manager en el archivo de configuracion, modificar y guardar los cambios.

  ![image](https://github.com/user-attachments/assets/eea33c4b-2514-489e-9bbd-1bde8bc796c2)

   Lineas de configuracion:

       # IBM Cloud Secrets Manager integration:
       com.instana.configuration.integration.vault:
         connection_url: {Secret_Manager_URL} # The address (URL) of the IBM Cloud Secrets Manager server instance(e.g. https://f022446e-1024-4aa9-a00c-72bf15aa9e7b.us-south.secrets-manager.appdomain.cloud)
         ibm_secrets_manager: {IAM_Key} # IAM Key that can be used to create access tokens
         secret_refresh_rate: 24 # This configuration option allows you to account for rotating credentials, refresh rate in hours, default 24

3. Configurar a nivel de plugin de Instana donde se necesitara el valor del secret.

   Ejemplo de configuracion para extraer el password de una BD SQL Server desde IBM Secret Manager:

   ![image](https://github.com/user-attachments/assets/d4e53918-2202-47b3-b835-5c96b07d7ac5)


   Configuracion en Yaml:

       # Mssql
       com.instana.plugin.mssql:
         user: sa
         password:
           configuration_from:
             type: vault
             secret_key:
               path: {Secret_ID}
               key: {Key_entry}
         port: '1433'
         poll_rate: 10 # In seconds. Poll rate can not be less than 1 seconds. If it is configured below 1 seconds then default value (1 seconds) will be set.
         top_queries_poll_rate: 120


4. Verificar en Instana la comunicacion con el sensor configurado, para este ejemplo sensor de SQL Server.

   ![image](https://github.com/user-attachments/assets/2d91d614-af46-4fec-9dee-bf357771d7f0)


















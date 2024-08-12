# Habilitación de Plugin Zabbix

## Prerequisitos:

1. Tener instalado un agente Instana.
2. Creación de un token de API en Zabbix con los permisos definidos a nivel de rol de usuario. Los permisos sobre los hosts asociados están vinculados a los permisos del usuario propietario del token en Zabbix.

   Lista de permisos de Api Token:

   - item.get
   - host.get
   - problem.get
   - event.get

## Configuración de Plugin

1. Ingresar al archivo de configuración del agente Instana

   Windows

       C:\Program Files\Instana\instana-agent\etc\instana\configuration.yaml

   Linux

       /opt/instana/agent/etc/instana/configuration.yaml

2. Ubicar las lineas para el plugin de Zabbix en el archivo de configuracion.

   ![image](https://github.com/user-attachments/assets/6165e7bb-330a-4190-b6f4-e14858a6b49e)

3. Proceder a modificar colocando los parametros del ambiente Zabbix destino a monitorear con Instana y guardar los cambios.

   Lineas de configuracion:

       #Zabbix
       com.instana.plugin.zabbix:
         enabled: true
         endpoint: 'http://{zabbix_host}/api_jsonrpc.php'
         token: '{Zabbix_Api_Token}'
         poll_rate: 10  # In seconds
         target_zone: {Custom_zone}

   Ejemplo de configuracion:

   ![image](https://github.com/user-attachments/assets/0dc42ea2-d29f-4bf1-8347-cd63c34238be)

4. Luego de realizar la configuración verificar en el módulo de Infrastructure de Instana.

   ![image](https://github.com/user-attachments/assets/4f0b3065-1979-4f2f-83e9-1f1a2168b5f3)





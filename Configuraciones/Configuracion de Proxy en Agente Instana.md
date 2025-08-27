# Configuración de Proxy en Agente Instana

Se requiere modificar los archivos mvn-settings.xml y com.instana.agent.main.sender.Backend.cfg.

## Prerrequisitos

- Ubicar los datos del host Instana "Instana backend address" y el key "Instana agent key".

  ![image](https://github.com/user-attachments/assets/12396c78-5a6d-455c-934d-a63a4ff3c3af)

  ![image](https://github.com/user-attachments/assets/d05c0e5d-550e-45e5-a56b-abcc4d8fdc07)

  ![image](https://github.com/user-attachments/assets/f2cbe35e-fdca-49c1-94a7-90e801ad2d87)


# Modificación del archivo mvn-settings.xml

1. Ingresar a la ruta del archivo en el directorio del agente Instana.

   Windows

       C:\Program Files\Instana\instana-agent\etc\mvn-settings.xml

   Linux

       /opt/instana/agent/etc/mvn-settings.xml

   Unix

       /opt/instana-agent/etc/mvn-settings.xml

2. Ubicar la seccion de usuario y contraseña para el repositorio de Instana, estas credenciales son usuario "_" y contraseña "Instana Agent Key" utilizado para la descarga de agentes.

       vi mvn-settings.xml

   ![image](https://github.com/user-attachments/assets/42ce3b60-3516-45ec-aea9-51b075736d83)

   ![image](https://github.com/user-attachments/assets/dd253fa3-05f8-4593-a70e-ddec3dd4b60e)

   Retirar los comentarios de la seccion proxies e ingresar los datos del servidor proxy utilizado. Si el proxy requiere autenticación, proporcionar las credenciales del usuario correspondiente y guardar los cambios realizados.
   En este ejemplo, la conexión se realiza vía HTTP al proxy con dirección IP 129.39.172.10 y puerto 3128, sin necesidad de autenticación.


# Modificación del archivo com.instana.agent.main.sender.Backend.cfg

1. Ingresar a la ruta del archivo en el directorio del agente Instana.

   Windows

       C:\Program Files\Instana\instana-agent\etc\instana\com.instana.agent.main.sender.Backend.cfg

   Linux

       /opt/instana/agent/etc/instana/com.instana.agent.main.sender.Backend.cfg

   Unix

       /opt/instana-agent/etc/instana/com.instana.agent.main.sender.Backend.cfg

2. Ubicar la seccion del host "Instana backend address" y el key "Instana Agent Key", donde el host corresponde al endpoint ingress de Instana asignado al tenant y el key "Instana Agent Key" utilizado para la descarga de agentes.

       vi com.instana.agent.main.sender.Backend.cfg

   ![image](https://github.com/user-attachments/assets/6de47274-bfd4-4b87-be70-ab3fc5ac8e74)

3. Retirar los comentarios de los parametros correspondientes al proxy, colocar los valores correspondientes al proxy a configurar.

   <img width="808" height="551" alt="image" src="https://github.com/user-attachments/assets/7750ab09-9a35-4319-a78a-56c60eb16deb" />

4. Guardar los cambios en el archivo y reiniciar el agente Instana para aplicar los cambios realizados.










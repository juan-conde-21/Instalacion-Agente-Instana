# Convertir Agente Instana Estatico a Dinamico

1. Detener el agente Instana.
  
2. Ingresar a la ruta donde esta instalado el agente Instana

   Windows

       C:\Program Files\Instana\instana-agent\

   Linux

       /opt/instana/agent/

3. Actualizar el archivo de referencia al repositorio de Instana, dentro del directorio de instana ubicar el archivo "/etc/org.ops4j.pax.url.mvn.cfg"

       cd /opt/instana/agent/etc/
       vi org.ops4j.pax.url.mvn.cfg

   Configuracion por defecto para agente estatico:

   ![image](https://github.com/user-attachments/assets/5f4eef43-5dda-40b1-8dfa-e5e5e1f4f450)

   Agregar la ruta para el repositorio utilizado por el agente dinamico:

   "https://artifact-public.instana.io/artifactory/features-public@id=features@snapshots@snapshotsUpdate=always,https://artifact-public.instana.io/artifactory/shared@id=shared@snapshots@snapshotsUpdate=always"

   ![image](https://github.com/user-attachments/assets/0441d0da-6a85-44fd-b4fa-034ba24a6e10)


4. Actualizar el archivo de referencia al modo de actualizacion del agente Instana, dentro del directorio de instana ubicar el archivo "/etc/instana/com.instana.agent.main.config.UpdateManager.cfg"

       cd /opt/instana/agent/etc/instana/
       vi com.instana.agent.main.config.UpdateManager.cfg

   Configuracion por defecto para agente estatico:

   ![image](https://github.com/user-attachments/assets/617c184e-fde0-4cd4-b112-74228842ddf2)

   Modificar el modo a AUTO utilizado por el agente dinamico:

   ![image](https://github.com/user-attachments/assets/b370d712-3403-48b3-8cba-0d5e8f54a6aa)


5. Actualizar el archivo de referencia a la version especifica del agente Instana en modo estatico, dentro del directorio de instana ubicar el archivo "/etc/instana/com.instana.agent.bootstrap.AgentBootstrap.cfg"

       cd /opt/instana/agent/etc/instana/com.instana.agent.bootstrap.AgentBootstrap.cfg
       vi com.instana.agent.bootstrap.AgentBootstrap.cfg

   Configuracion por defecto para agente estatico:

   ![image](https://github.com/user-attachments/assets/c8926ab4-f1c5-4e27-aa6b-2b7d869eb7f5)

   Comentar la version utilizada por el agente estatico para eliminar la asocicacion a una version especifica:

   ![image](https://github.com/user-attachments/assets/ed694600-2e59-45c2-b73f-20ebe9c56c3c)


6. Eliminar la referencia a los archivos que definen todas las dependencias de necesarias para el agente y módulos en específico.

   Linux
    
       find /opt/instana/agent/system/ -type d -name '1.0.0-SNAPSHOT' -exec rm -rv {} \;
    
    Windows
    
       for /d /r "C:\Program Files\Instana\instana-agent\system" %d in (*) do (
          if /i "%~nxd"=="1.0.0-SNAPSHOT" rmdir /s /q "%d"


7. Iniciar el agente Instana y verificar la versión actualizada.

   ![image](https://github.com/user-attachments/assets/31b202da-466c-4dc1-9838-ee11ece44b37)

   *Para casos donde se utiliza un proxy para conectarse al tenant de Instana se debe asegurar que el proxy tenga conexion habilitada al dominio "artifact-public.instana.io" para que pueda actualizar el agente.



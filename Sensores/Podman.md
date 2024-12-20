# Habilitación de Sensor Podman

## Prerrequisitos:

1. Agente Instana desplegado([Instalación](https://github.com/juan-conde-21/Instalacion-Agente-Instana/blob/main/README.md))


## Configuración de Sensor

1. Ingresar al archivo de configuración del agente Instana

       /opt/instana/agent/etc/instana/

2. Ubicar las lineas para el sensor Podman en el archivo de configuracion.

       vi configuration.yaml

   ![image](https://github.com/user-attachments/assets/91d0023e-182f-407a-8cb9-cdc9cba20388)

   Retirar los comentarios y guardar el archivo.

   ![image](https://github.com/user-attachments/assets/a8942379-9b5f-4bdc-9773-543975dce716)

4. Con usuario root habilitar podman.sock socket para acceder a las metricas de podman.

       systemctl --user enable --now podman.socket
       systemctl --user status podman.socket

5. En el caso de utilizar usurios diferentes a root para ejecutar contenedores no privilegiados como el usuario podman, tambien se debe habilitar el acceso a las metricas de podman. Se muestra el ejemplo con el usuario podmanuser.

   - Ejecutar con usuario root
  
         su - podmanuser
         mkdir -p ~/.config/containers

   - Ejecutar con usuario root
       
         loginctl enable-linger podmanuser
 
   - Ejecutar con usuario no privilegiado (podmanuser)

         export XDG_RUNTIME_DIR=/run/user/$(id -u)
         /usr/lib/systemd/systemd --user
         systemctl --user enable --now podman.socket

6. Luego de aplicar los cambios se debe reiniciar el agente Instana.(Con usuario root)

   Ejecutar el comando:

       systemctl restart instana-agent
   
7. Verificar que el contendor se encuentre monitoreado en Instana.

   ![image](https://github.com/user-attachments/assets/7ca8a85e-7cdd-4aee-ac21-c038f5cffb53)

   







# Configuración de Squid Proxy

1. Instalar Squid proxy con permisos de root.

   Ubuntu:
   
       apt install -y squid

   Red Hat / Centos:

       yum install -y squid


2. Ingresar a la ruta de configuracion de Squid proxy y utilizar el archivo de ejemplo ([Configuracion](https://github.com/juan-conde-21/Instalacion-Agente-Instana/blob/main/Configuraciones/squid.conf]))

       vi /etc/squid/squid.conf

3. Modificar las urls publicas de acuerdo con el tenant Instana utilizado, en este ejemplo se utiliza un tenant desplegado en la region orange.

   ![image](https://github.com/user-attachments/assets/96058ad3-9ff3-434f-9913-cda274a70469)

4. Guardar los cambios y reiniciar el servicio de Squid proxy.

       systemctl restart squid



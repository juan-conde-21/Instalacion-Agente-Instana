# Configuración de Squid Proxy

# Sistema Operativo Linux

1. Instalar Squid proxy con permisos de root.

   Ubuntu:
   
       apt install -y squid

   Red Hat / Centos:

       yum install -y squid


2. Ingresar a la ruta de configuracion de Squid proxy y utilizar el archivo de ejemplo ([Configuracion](https://github.com/juan-conde-21/Instalacion-Agente-Instana/blob/main/Configuraciones/squid.conf))

       vi /etc/squid/squid.conf

3. Modificar las urls publicas de acuerdo con el tenant Instana utilizado, en este ejemplo se utiliza un tenant desplegado en la region orange.

   ![image](https://github.com/user-attachments/assets/96058ad3-9ff3-434f-9913-cda274a70469)

4. Guardar los cambios y reiniciar el servicio de Squid proxy.

       systemctl restart squid


# Sistema Operativo Windows

1. Descargar el instalador de la siguiente pagina web https://squid.diladele.com/

   ![image](https://github.com/user-attachments/assets/911f0351-948c-4b19-89a8-84ab71771ee0)


2. Ejecutar el instalador para iniciar la instalación.

   ![image](https://github.com/user-attachments/assets/1010368d-64fe-4dd0-bac3-3233c2174f8b)

   ![image](https://github.com/user-attachments/assets/8306e5a9-89dc-42f4-be59-a580a37d89af)

   ![image](https://github.com/user-attachments/assets/51e3f581-3caf-47ed-b41c-18dcf4bd2b79)

   ![image](https://github.com/user-attachments/assets/55d52e0f-2485-42f8-a8c9-0b5824ce6ede)

   ![image](https://github.com/user-attachments/assets/eead2d1f-9abd-44e3-bd09-3ecd7c223b56)

   ![image](https://github.com/user-attachments/assets/47da90a4-5e7a-4c24-8039-b1d2a6ec5a2c)

3. Habilitar el puerto TCP 3128 para conectarse a través del proxy Squid, habilitar el puerto TCP 3128 en las reglas de entrada del firewall.

   ![image](https://github.com/user-attachments/assets/3fe93fe1-9bdf-426a-a645-3c1ca9dac934)

4. Crear una nueva regla para permitir el puerto 3128 en el servidor Squid.

   ![image](https://github.com/user-attachments/assets/9f33fc50-71a9-4e4f-a541-561fb92c396b)

5. En la página Tipo de regla , seleccione el botón junto a Puerto y haga clic en Next.

   ![image](https://github.com/user-attachments/assets/5d093c28-cdc7-4712-b113-680fc097006a)

6. En Protocolo y puertos , seleccione TCP y seleccione Puertos locales específicos e ingrese 3128 luego haga clic en Next. 

   ![image](https://github.com/user-attachments/assets/21cccdf7-0a6b-4ef1-ba5d-0b273a5a30f6)

7. A continuación, haga clic en Permitir la conexión y haga clic en Next para continuar.

   ![image](https://github.com/user-attachments/assets/f8a11ed3-d348-48c9-a60c-88db986dd090)

8. En la  pestaña Perfil  , debe seleccionar las siguientes opciones y marcar las casillas de Dominio , Privado y Público, luego hacer clic en          Next para continuar.

   ![image](https://github.com/user-attachments/assets/96641b0e-b86c-4b53-845e-1452dde88db8)

9. En la sección Nombre , puede especificar un nombre fácil de identificar para la regla y luego hacer clic en Finish.

   ![image](https://github.com/user-attachments/assets/cd5f912a-6b4f-4218-a649-76f50d3dc425)

10. Paa configurar el servidor Squid, dirigirse a la barra inferior derecha de la pantalla y ubicar el icono de Squid, dar clic derecho para continuar.

    ![image](https://github.com/user-attachments/assets/dbabbfaf-586b-45fa-901d-9954b8f82429)

11. Se mostraran las opciones de Squid, donde debemos seleccionar "Open Squid Configuration" para poder editar la configuracion.

    ![image](https://github.com/user-attachments/assets/ac616b68-691a-4166-9422-49170da0683d)

    ![image](https://github.com/user-attachments/assets/fc8c93bc-1313-4286-9cbc-37dbf7c85371)

12. Reemplazar el contenido por el que se tiene a nivel del siguiente archivo ([Configuracion](https://github.com/juan-conde-21/Instalacion-Agente-Instana/blob/main/Configuraciones/squid.conf))

13. Para aplicar la configuración del paso previo, se debe reiniciar el servicio de Squid en Windows a nivel del administrador de tareas de Windows.

    ![image](https://github.com/user-attachments/assets/4a60b9d5-216e-45a4-8abd-0d0780241358)

   












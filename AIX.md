# Instalación de Agente Instana en plataforma UNIX

1. Dirigirse al módulo de Agentes en la consola de Instana.

   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/14ac8ed5-4346-4256-9c01-0eb3f7d33a5c)

2. Seleccionar Install Agents

   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/6acee1fb-f4ed-4427-9282-310c2d7ab8be)

3. Buscar la plataforma Unix y seleccionar el instalador dependiendo de la arquitectura del servidor donde se va a desplegar.

   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/db7015f0-fddc-49a3-983d-cb7c8c9582d0)

   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/a6aff306-bc97-49fc-9f06-fe0daa01f4b8)

4. Descarga el IBM Semeru Runtime JDK/J9 11 desde la Url especificada:

   https://github.com/ibmruntimes/semeru11-binaries/releases/download/jdk-11.0.14.1%2B1_openj9-0.30.1/ibm-semeru-open-jdk_ppc64_aix_11.0.14.1_1_openj9-0.30.1.tar.gz

5. Copiar y descomprimir los instaladores en la ruta /opt del servidor a monitorear.

   Ingresar a la ruta /opt

       cd /opt

   Descomprimir el agente Instana en la carpeta

       gunzip instana-agent-aix-ppc-64bit.tar
       tar -xvf instana-agent-aix-ppc-64bit.tar

   Descomprimir el archivo IBM OpenJ9 JDK 11

       gunzip ibm-semeru-open-jdk_ppc64_aix_11.0.14.1_1_openj9-0.30.1.tar.gz

       tar -xvf ibm-semeru-open-jdk_ppc64_aix_11.0.14.1_1_openj9-0.30.1.tar

   Renombrar la carpeta IBM OpenJ9 JDK 11 descomprimida, a jvm.

       mv jdk-11.0.14.1+1 jvm

   Mover la carpeta jvm hacia la ruta del agente /opt/instana-agent/

       mv jvm /opt/instana-agent/ 

6. Iniciar el agente Instana desde la ruta:  /opt/instana-agent/bin/

   Ejecutar los siguientes comandos:
   
       cd  /opt/instana-agent/bin/
       ./start
          
7. Validación que el agente se encuentre operativo.

   Ejecutar los siguientes comandos:
   
       cd  /opt/instana-agent/bin/
       ./status

   Resultado del comando:

      ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/cbf816d0-f884-44ce-8e27-47f70cdee6f3)


8. Configurar Inicio automático del agente Instana, para ello editar el archivo inittab.

   Ejecutar los siguientes comandos:

       vi /etc/inittab
         
   Al final del archivo inittab, agregar la siguiente línea:

       instana:once:/opt/instana-agent/bin/start > /dev/null



   

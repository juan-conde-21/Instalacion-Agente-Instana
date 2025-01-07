# Instalación de Agente Instana en plataforma UNIX

## Prerrequisitos:

- Espacio disponible en filesystem /opt/ mínimo 3 GB.

## Instalación de Agente

1. Dirigirse al módulo de Agentes en la consola de Instana.

   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/14ac8ed5-4346-4256-9c01-0eb3f7d33a5c)

2. Seleccionar Install Agents

   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/6acee1fb-f4ed-4427-9282-310c2d7ab8be)

3. Buscar la plataforma Unix y seleccionar el instalador dependiendo de la arquitectura del servidor donde se va a desplegar.

   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/db7015f0-fddc-49a3-983d-cb7c8c9582d0)

   - AIX

   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/a6aff306-bc97-49fc-9f06-fe0daa01f4b8)

   - Solaris

   ![image](https://github.com/user-attachments/assets/b15efa6c-30c0-4fb5-937d-adffc0a61b7b)


4. Descarga la versión de Java JDK/J9 11 desde la Url indicada.

   - AIX

     https://github.com/ibmruntimes/semeru11-binaries/releases/download/jdk-11.0.14.1%2B1_openj9-0.30.1/ibm-semeru-open-jdk_ppc64_aix_11.0.14.1_1_openj9-0.30.1.tar.gz

   - Solaris

     https://cdn.azul.com/zulu/bin/zulu11.76.21-ca-jdk11.0.25-solaris_sparcv9.zip

   **Observación:** Para el caso de Solaris versión 10 utilizar java JDK 1.8.

5. Copiar y descomprimir los instaladores en la ruta /opt del servidor a monitorear. (Con usuario root)

   Ingresar a la ruta /opt

       cd /opt

   - AIX

      Descomprimir el agente Instana en la carpeta
   
          gunzip instana-agent-aix-ppc-64bit.tar.gz
          tar -xvf instana-agent-aix-ppc-64bit.tar

      **Observación:** Asegurarse de que el comando tar complete su ejecución correctamente, sin generar errores ni advertencias relacionadas con el tamaño excedido.
   
      Descomprimir el instalador de Java JDK/J9 11
   
          gunzip ibm-semeru-open-jdk_ppc64_aix_11.0.14.1_1_openj9-0.30.1.tar.gz
   
          tar -xvf ibm-semeru-open-jdk_ppc64_aix_11.0.14.1_1_openj9-0.30.1.tar
   
      Renombrar la carpeta IBM OpenJ9 JDK 11 descomprimida, a jvm.
   
          mv jdk-11.0.14.1+1 jvm

   - Solaris

      Descomprimir el agente Instana en la carpeta
   
          gunzip instana-agent-solaris-sparc-64bit.tar.gz
          tar -xvf instana-agent-solaris-sparc-64bit.tar

      **Observación:** Asegurarse de que el comando tar complete su ejecución correctamente, sin generar errores ni advertencias relacionadas con el tamaño excedido.
   
      Descomprimir el instalador de Java JDK/J9 11
   
          unzip zulu11.76.21-ca-jdk11.0.25-solaris_sparcv9.zip
   
      Renombrar la carpeta IBM OpenJ9 JDK 11 descomprimida, a jvm.
   
          mv zulu11.76.21-ca-jdk11.0.25-solaris jvm


   Mover la carpeta jvm hacia la ruta del agente /opt/instana-agent/

       mv jvm /opt/instana-agent/ 


6. Editar el profile del usuario root e incluir la variable de entorno del JAVA utilizado.

       vi ~/.bashrc

   Agregar las siguiente lineas indicando la ubicacion del Java utilizado.

       export JAVA_HOME=/opt/instana-agent/jvm
       export PATH=$JAVA_HOME/bin:$PATH

   Volver a cargar el profile en la sesion actual.

       . ~/.bashrc
   
7. Iniciar el agente Instana desde la ruta:  /opt/instana-agent/bin/

   Ejecutar los siguientes comandos:
   
       cd  /opt/instana-agent/bin/
       ./start
          
8. Validación que el agente se encuentre operativo.

   Ejecutar los siguientes comandos:
   
       cd  /opt/instana-agent/bin/
       ./status

   Resultado del comando:

      ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/cbf816d0-f884-44ce-8e27-47f70cdee6f3)


9. Configurar Inicio automático del agente Instana, para ello editar el archivo inittab.

   Ejecutar los siguientes comandos:

       vi /etc/inittab
         
   Al final del archivo inittab, agregar la siguiente línea:

       instana:3:once:/opt/instana-agent/bin/start > /dev/null



   

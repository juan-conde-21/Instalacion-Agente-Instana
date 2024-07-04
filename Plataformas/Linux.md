# Instalación de Agente Instana en plataforma Linux

1. Dirigirse al módulo de Agentes en la consola de Instana.

   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/14ac8ed5-4346-4256-9c01-0eb3f7d33a5c)


2. Seleccionar Install Agents

   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/6acee1fb-f4ed-4427-9282-310c2d7ab8be)

3. Buscar la plataforma Linux y seleccionar el instalador dependiendo con la plataforma donde se va a desplegar.

   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/47162d4f-ac46-464f-bee7-9857be118684)

4. Se mostrarán los comandos de instalacion del agente en la plataforma linux los cuales requerimos copiar y ejecutar en el servidor a monitorear.
 
   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/3d21a9b1-6e9c-4eff-b4d6-62adf79d44eb)

5. Ingresar al servidor Linux con usuario root y ejecutar los comandos copiados en el paso anterior. Ingresar la letra Y para aceptar la instalación y continuar.

   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/838465ef-2424-49cb-90e9-d6208edd0128)

   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/0ee1a272-e66e-40f3-908a-10537d413856)

6. Configuración de Zona para el agente instalado.

   Ingresar a la ruta del archivo de configuración:

       cd /opt/instana/agent/etc/instana/

   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/9f5db656-f58c-437c-9657-02516b95ecdc)

   Ejecutar el comando vi para editar:

       vi configuration.yaml

   Ubicar la línea donde se encuentra la seccipon "com.instana.plugin.generic.hardware"

   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/e2ffa785-1d67-4c5e-9145-c9ec01c6cc5d)


   Proceder a descomentar y colocar el nombre de la zona definida para el host.(Retirar los caracteres # para descomentar)
   
   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/c38090e2-39d7-4463-be57-898b5654635e)

7. Verificar que el nuevo agente se encuentre reportando en la consola de Instana.

   Ingresar al módulo de infraestructura

   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/f7b72266-d585-4b06-bdd4-12075b2424c9)

   Buscar el hostname en la barra de consultas, ejemplo entity.host.name:"ubuntu-server" 

   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/df3f42fe-6c9c-4915-a75f-4624ec8c0b37)



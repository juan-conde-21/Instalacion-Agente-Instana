# Instalación de Agente Instana en plataforma Windows

1. Dirigirse al módulo de Agentes en la consola de Instana.

   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/14ac8ed5-4346-4256-9c01-0eb3f7d33a5c)


2. Seleccionar Install Agents

   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/6acee1fb-f4ed-4427-9282-310c2d7ab8be)

3. Buscar la plataforma windows y seleccionar el instalador dependiendo con la plataforma donde se va a desplegar.

   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/e0161efa-ff5b-4f44-8325-6ac0e06b6b92)

4. Descargar el instalador de acuerdo como se muestra, debajo se muestran los valores requeridos para la instalacion backend address y agent key que se utilizaran en el siguiente paso.
 
   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/e8d620ad-dbca-4ae0-a4af-cb1a5765cf94)

5. Ejecutar el instalador con permisos de administrador.

   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/13171c64-bb99-4cba-9c83-174673cb4577)

6. Se mostrará el asistente de instalación.

   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/69e1a1ae-1411-48ab-b6d9-13009f012f3c)


   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/35c82eab-d76f-4b94-a374-466c073e7a3f)

   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/64775970-10c6-4c13-8ce3-da3f105a5305)

7. En la siguiente ventana colocar los puntos descritos en el paso 4 de este procedimiento.

   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/3c79b7a0-c987-4527-a812-e72b40c1138d)

   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/8e443592-0dca-41bf-a288-2e25b0cc0514)

   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/e5badcd4-e936-4626-9a6d-da42109d8de6)

   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/f16e0d0e-f811-4494-83a8-08cac19b7b11)

   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/388a420b-9940-4151-a41d-e15b98b18bcc)


8. Configuración de Zona para el agente instalado.

   Ingresar a la ruta del archivo de configuración:
   
       C:\Program Files\Instana\instana-agent\etc\instana

   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/d33a94fa-6aa7-450b-8f78-36fb5f19fcc8)

   Ubicar la línea donde se encuentra la seccipon "com.instana.plugin.generic.hardware"

   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/f46aa0b6-2c2d-403d-b973-c57b1d2da165)

   Proceder a descomentar y colocar el nombre de la zona definida para el host.(Retirar los caracteres # para descomentar)

   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/104f6c0b-fb37-4f70-ab18-71ada9677a5a)

9. Verificar que el nuevo agente se encuentre reportando en la consola de Instana.

   Ingresar al módulo de infraestructura

   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/f7b72266-d585-4b06-bdd4-12075b2424c9)

   Buscar el hostname en la barra de consultas, ejemplo entity.host.name:"WIN-R0UTIF1RLS4" 

   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/f4739ed9-e648-4aba-b540-4100ea5b7569)

   




   








# Habilitación de Sensor VMware vSphere

1. Ingresar al archivo de configuración del agente Instana

   Windows

       C:\Program Files\Instana\instana-agent\etc\instana

   Linux

       /opt/instana/agent/etc/instana/

2. Ubicar las lineas para el sensor de vsphere en el archivo de configuracion.

       vi configuration.yaml

   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/3059bd09-8641-465d-9344-1097fba5c4ed)

3. Descomentar las lineas del sensor vsphere y realizar las modificaciones de acuerdo con el ambiente a configurar.

   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/fe1a0536-6200-4403-830f-adb477dd2b5e)

4. Guardar los cambios y verificar que el cluster VMware se encuentre reportando.

   En el módulo Platform ubicar el submódulo vSphere:

   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/a1d6466c-0496-40ca-a59f-6fd342a75f1d)

   Se mostrara el clúster descubierto:

   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/e6d9be04-5490-4ae2-b2e7-0b56586d49db)

   






# Habilitación de Sensor IBM DataPower

1. Ingresar al archivo de configuración del agente Instana

   Windows

       C:\Program Files\Instana\instana-agent\etc\instana

   Linux

       /opt/instana/agent/etc/instana/

2. Ubicar las lineas para el sensor de IBM DataPower en el archivo de configuracion.

       vi configuration.yaml


3. Descomentar las lineas del sensor IBM DataPower y realizar las modificaciones de acuerdo con el ambiente a configurar.


4. Guardar los cambios y verificar que el cluster IBM DataPower se encuentre reportando.

   En el módulo Platform ubicar el submódulo IBM DataPower:


   Se mostrara el clúster descubierto:

   

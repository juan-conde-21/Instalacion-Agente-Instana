# Habilitación de Sensor SAP ABAP

1. Ingresar al archivo de configuración del agente Instana

   Windows

       C:\Program Files\Instana\instana-agent\etc\instana

   Linux

       /opt/instana/agent/etc/instana/

2. Ubicar las lineas para el sensor de SAP en el archivo de configuracion.

       vi configuration.yaml

   ![image](https://github.com/user-attachments/assets/e34b0db7-3cda-424e-b250-4990e2d70743)

4. Descomentar las lineas del sensor IBM DataPower y realizar las modificaciones de acuerdo con el ambiente a configurar.


5. Guardar los cambios y verificar que el cluster IBM DataPower se encuentre reportando.

   En el módulo Infrastructure ubicar el detalle de los componentes de Infraestructura, luego ubicar los componentes de DataPower descubiertos:


   Se mostrara el clúster descubierto: Filtrar por "entity.type:ibmDataPower.cluster"

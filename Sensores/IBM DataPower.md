# Habilitación de Sensor IBM DataPower

1. Ingresar al archivo de configuración del agente Instana

   Windows

       C:\Program Files\Instana\instana-agent\etc\instana

   Linux

       /opt/instana/agent/etc/instana/

2. Ubicar las lineas para el sensor de IBM DataPower en el archivo de configuracion.

       vi configuration.yaml

   ![image](https://github.com/user-attachments/assets/c8f11dcb-5756-428c-ac73-f3ea07216139)

3. Descomentar las lineas del sensor IBM DataPower y realizar las modificaciones de acuerdo con el ambiente a configurar.

   ![image](https://github.com/user-attachments/assets/f500abda-b258-45c9-8e64-74de5f254e2c)


4. Guardar los cambios y verificar que el cluster IBM DataPower se encuentre reportando.

   En el módulo Infrastructure ubicar el detalle de los componentes de Infraestructura, luego ubicar los componentes de DataPower descubiertos:

   ![image](https://github.com/user-attachments/assets/2ca8a352-3836-47d7-9511-3a317f3db772)

   ![image](https://github.com/user-attachments/assets/a42d5f0e-c0c7-417e-b1d3-617b8102d005)

   Se mostrara el clúster descubierto: Filtrar por "entity.type:ibmDataPower.cluster"

   ![image](https://github.com/user-attachments/assets/1e8ff4a5-f0f7-4df2-ad11-9da6f58a9574)



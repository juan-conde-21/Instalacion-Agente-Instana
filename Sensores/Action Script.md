# Habilitación de Sensor Action Script

1. Ingresar al archivo de configuración del agente Instana

   Windows

       C:\Program Files\Instana\instana-agent\etc\instana

   Linux

       /opt/instana/agent/etc/instana/

2. Ubicar las lineas para el sensor de action script en el archivo de configuracion.

       vi configuration.yaml

   ![image](https://github.com/user-attachments/assets/c6afddcb-8128-4bf4-938e-f1ad405a74b2)

3. Descomentar las lineas del sensor action script y realizar las modificaciones de acuerdo con el sistema operativo a configurar como se muestra a continuación:

   Windows

   ![image](https://github.com/user-attachments/assets/e8af6c53-05a0-4006-93fe-1925a3f31243)

   *Se debe especificar la constraseña del usuario, ademas de colocar la ruta donde se ejecutarán los scripts "scriptExecutionHome" especificado para la ejecucion de scripts. El usuario debe tener permisos de lectura y escritura sobre esta ruta.

   Linux

   ![image](https://github.com/user-attachments/assets/94823b82-b137-4205-a755-9ab0074ec7ab)

   *Para Linux solo debemos colocar el nombre del usuario que ejecutara los scripts.


6. Guardar los cambios y verificar en el modulo de automation. Ahora cuando seleccionemos una accion para probar se mostrará el host que configuramos en el paso previo.

   ![image](https://github.com/user-attachments/assets/ad34f48d-96c1-41dc-98df-ba91abf43f44)

   ![image](https://github.com/user-attachments/assets/ab81ee40-7540-40a1-8e2b-fdd1f1fb4ea2)

   ![image](https://github.com/user-attachments/assets/e4547612-9afe-4047-b9e3-1235b4d07e95)

   ![image](https://github.com/user-attachments/assets/c69a711a-173f-4cb2-beec-7aa76a57fa5d)

   ![image](https://github.com/user-attachments/assets/870061c5-e4db-465c-9e79-e38fd1c03d32)







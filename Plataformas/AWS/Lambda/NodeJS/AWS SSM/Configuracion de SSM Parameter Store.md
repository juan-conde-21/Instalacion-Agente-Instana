
# AWS Lambda Integracion con AWS SSM Parameter Store 

Se detalla la integración de una funcion AWS Lambda con AWS SSM Parameter Store para almacenar el valor del key de Instana.

## Prerrequisito:

- Utilizar la version de lambda layer 214 o superior (arn:aws:lambda:us-east-2:410797082306:layer:instana-nodejs:214)

## Procedimiento:

1. Crear el AWS SSM Parameter Store que almacenara el valor del agentkey de Instana.

   ![image](https://github.com/user-attachments/assets/7d52ee2f-29a5-4036-b365-dec56d322b17)


2. Editar la funcion Lambda y retirar la referencia a la variable de entorno INSTANA_AGENT_KEY. Luego agregar la variable INSTANA_SSM_PARAM_NAME con el valor del nombre del parameter creado en el paso anterior.

   ![image](https://github.com/user-attachments/assets/4c37700d-7f46-4502-8ff8-cf69398efd74)

   
3. Agregar los permisos de lectura del Parameter store a nivel del rol que utiliza la funcion Lambda.

   ![image](https://github.com/user-attachments/assets/9afb75fd-fc40-44a1-9453-87d87589f655)

   ![image](https://github.com/user-attachments/assets/d34fd526-20db-4a95-bfc4-0fd12f00ada2)

  
4. Realizar las pruebas de ejecucion del servicio Lambda.

   ![image](https://github.com/user-attachments/assets/bf347056-7ca8-4be5-a451-64a0b515a3ca)

5. Verificar el envio de trazas en Instana.

   ![image](https://github.com/user-attachments/assets/ae25544f-e7a6-41a7-b718-61682afc5446)


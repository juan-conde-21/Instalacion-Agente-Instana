# AWS Lambda 

Se detalla la instrumentación de una funcion AWS Lambda con Instana.

1. Crear una funcion Lambda con el runtime Node.js 16.x y crear el rol de ejecucion "serverless-api-role"

![image](https://github.com/juan-conde-21/aws_lambda/assets/13276404/619ec782-2bbe-4ce2-8a5c-233a1cd58ac6)

2. Editar la funcion Lambda, para este ejemplo se agrega el codigo del archivo "index.js" del repositorio y se coloca la misma region donde se encuentran desplegados los servicios, luego se despliegan los cambios.

![image](https://github.com/juan-conde-21/aws_lambda/assets/13276404/a0d7cd5f-60d5-4e33-9c7d-5201413eeeb4)

3. Agregar un nuevo Layer en el servicio Lambda, se utilizara para la instrumentacion con instana.

  ![image](https://github.com/juan-conde-21/aws_lambda/assets/13276404/603e3121-a1c4-4141-aafa-5c9f4eb38324)
  
  El formato del ARN (arn:aws:lambda:us-east-1:410797082306:layer:instana-nodejs:177) para el Layer debe referenciar a la region donde se desplegaron los servicios, luego verificar la validez del layer.
  
  **Revisar el tipo de arquitectura y version de layer a utilizar** ([Documentacion](https://www.ibm.com/docs/en/instana-observability/current?topic=lambda-aws-native-tracing-nodejs#instana-lambda-layers))
  
  ![image](https://github.com/juan-conde-21/aws_lambda/assets/13276404/3644ff62-61ed-4a5e-9665-9662f08f0991)
  
4. Editar el handler (instana-aws-lambda-auto-wrap.handler) de la funcion Lambda referenciando al agente instana.

![image](https://github.com/juan-conde-21/aws_lambda/assets/13276404/fe852db4-6011-40a3-88ba-626ba5896a5f)

![image](https://github.com/juan-conde-21/aws_lambda/assets/13276404/162076bb-2d9e-42f7-ac55-37853ee88651)

5. Agregar las siguientes variables de entorno en la funcion Lambda.

  - INSTANA_AGENT_KEY : key del tenant Instana SaaS para la comunicacion con el tenant.
  - INSTANA_ENDPOINT_URL : Backend Instana SaaS.
  - LAMBDA_HANDLER : Handler actual de la funcion.

  ![image](https://github.com/juan-conde-21/aws_lambda/assets/13276404/eadf30df-76d7-4f2b-9b50-dd01c8bf3642)

6. Realizar las pruebas a nivel de la aplicacion desplegada, para este ejemplo se valido via postman.

  Registro de Productos
  
  ![image](https://github.com/juan-conde-21/aws_lambda/assets/13276404/48235037-2124-4ddd-9d03-d386abaa740a)

  Listar Productos

  ![image](https://github.com/juan-conde-21/aws_lambda/assets/13276404/0b7173a1-87c2-468f-8ef8-5b7e57e6ebcb)


7. Validar en la consola de Instana.

  ![image](https://github.com/juan-conde-21/aws_lambda/assets/13276404/b4d1ca07-874b-450d-994d-13d3bde3927e)
  
  ![image](https://github.com/juan-conde-21/aws_lambda/assets/13276404/5df8d108-3e19-425b-832d-fd6e34344fe9)
  
  ![image](https://github.com/juan-conde-21/aws_lambda/assets/13276404/89eb41a0-2d09-4e27-9404-e4fef62d7280)
  
  ![image](https://github.com/juan-conde-21/aws_lambda/assets/13276404/89d8df37-f48b-4de0-88d1-9bd7789f44dd)











#Configuracion de Trace SDK para NodeJS en servicio AWS Lambda

##Prerequisitos:

- Instalar Instana Layer en lambda para NodeJS ([Tracing Layer AWS Lambda NodeJS](https://github.com/juan-conde-21/Instalacion-Agente-Instana/blob/main/Plataformas/AWS/Lambda/NodeJS/Tracing%20Layer.md))

##Procedimiento

1. Importar el módulo Lambda de Instana en el código de la aplicación.

       import instana from '@instana/aws-lambda';

2. Acceder al span automatica autogenerado por Instana al momento de realizar la invocación del lambda.

       const span = instana.currentSpan();

3. Validar la existencia del span antes de proceder con la ejecución del codigo de la aplicación. (Opcional)

       // Verificar si el span actual está disponible
       if (!span) {
         console.error("Instana span no está disponible");
         return {
           statusCode: 500,
           body: JSON.stringify({ error: "No se pudo acceder al span actual." }),
         };
       }

4. Agregar la metadata adicional en el span actual mediante en método annotate como se muestra a continuación.

   Es mandatorio agregar el prefijo ***"sdk.custom.tags."*** para la clave del nombre de la metadata agregada. Formato (key,value) donde value es de tipo string.

     Ejemplo para valores individuales:

       // Anotar valores en el span
       span.annotate('sdk.custom.tags.num1', "" + num1);
       span.annotate('sdk.custom.tags.num2', "" + num2);

     Ejemplo para cadenas json:

       // Anotar valores del span
       span.annotate('sdk.custom.tags.span', "" + JSON.stringify(span, null, 2));
   
5. Ejemplo de metadata reportada en las trazas capturadas en Instana.

   ![image](https://github.com/user-attachments/assets/49fa097e-85c9-42a1-98c5-8411af58677b)









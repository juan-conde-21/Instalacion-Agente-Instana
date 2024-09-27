import instana from '@instana/aws-lambda';

export const handler = async (event) => {
  let response;

  // Accede al span actual utilizando instana.currentSpan()
  const span = instana.currentSpan();

  // Verificar si el span actual está disponible
  if (!span) {
    console.error("Instana span no está disponible");
    return {
      statusCode: 500,
      body: JSON.stringify({ error: "No se pudo acceder al span actual." }),
    };
  }

  console.log("Instana span activo:", span);
  
  // Anotar valores del span
  span.annotate('sdk.custom.tags.span', "" + JSON.stringify(span, null, 2));

  // Verificar la ruta en el event.rawPath
  switch (event.rawPath) {
    case "/suma": {
      const num1 = parseFloat(event.queryStringParameters?.num1);
      const num2 = parseFloat(event.queryStringParameters?.num2);

      if (isNaN(num1) || isNaN(num2)) {
        response = {
          statusCode: 400,
          body: JSON.stringify({ error: "Debe proporcionar dos números válidos en la URL." }),
        };
      } else {
        const sum = num1 + num2;
          
        // Anotar valores en el span
        span.annotate('sdk.custom.tags.suma', "" + sum);

        response = {
          statusCode: 200,
          body: JSON.stringify({ message: `La suma es ${sum}` }),
        };
      }
        
      // Anotar valores en el span
      span.annotate('sdk.custom.tags.num1', "" + num1);
      span.annotate('sdk.custom.tags.num2', "" + num2);
        

      break;
    }

    case "/hola": {
      response = {
        statusCode: 200,
        body: JSON.stringify({ message: "Hola Lambda!" }),
      };
      break;
    }

    case "/generarcodigo": {
      const body = JSON.parse(event.body);
      const { idusuario, nombre, edad } = body;

      if (!idusuario || !nombre || typeof edad !== "number") {
        response = {
          statusCode: 400,
          body: JSON.stringify({ error: "Debe proporcionar idusuario, nombre y edad válidos." }),
        };
      } else {

        // Generar código aleatorio
        const randomNumber = Math.floor(10000 + Math.random() * 90000);
        const randomLetters = String.fromCharCode(65 + Math.floor(Math.random() * 26)) + 
                              String.fromCharCode(65 + Math.floor(Math.random() * 26));
        const codigo = `${randomNumber}${randomLetters}`;

        // Anotar el código generado en el span
        span.annotate('sdk.custom.tags.codigo', "" + codigo);

        response = {
          statusCode: 200,
          body: JSON.stringify({
            idusuario,
            nombre,
            edad,
            codigo: codigo,
          }),
        };
      }
        
      // Anotar valores en el span
      span.annotate('sdk.custom.tags.idusuario', "" + idusuario);
      span.annotate('sdk.custom.tags.nombre', "" + nombre);
      span.annotate('sdk.custom.tags.edad', "" + edad);
        
        
      break;
    }
    default: {
      response = {
        statusCode: 404,
        body: JSON.stringify({ error: "Endpoint no encontrado." }),
      };
    }
  }


  // Log detallado del response
  console.log("Response enviado:", response);

  return response;
};

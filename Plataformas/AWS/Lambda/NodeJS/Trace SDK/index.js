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

  //Texto con formato de log en json de prueba
  const texto = "{\"severityText\": \"INFO\", \"request\": {\"destination\": \"huacabala@gmail.com\", \"subject\": \"Recuperación de contraseña\", \"type\": 3, \"template\": \"recovery_password\", \"parameters\": {\"baseUrl\": \"https://centrodemonitoreo.rimac.com\", \"url\": \"https://centrodemonitoreo.rimac.com/recovery/UhL4I_flA\", \"email\": \"huacabala@gmail.com\"}}, \"response\": {\"mailId\": 9978954, \"code\": 200, \"body\": {\"message\": \"CORREO ENVIADO - 010001923504b86c-613bbc9c-4251-44de-8f3e-f092f81e086c-000000\"}, \"message\": \"CONSULTA TERMINADA\"}, \"status\": \"unique\", \"name\": \"mail\", \"action\": \"send\", \"traceId\": \"672c26ff-7d3d-4cd1-9a94-0c3e239f17a1\", \"resource\": \"UE2COMPRODLMBCMOPUBLIC\", \"createdAt\": \"2024-09-27T19:45:54.937Z\",\"severityText2\": \"INFO\", \"request2\": {\"destination2\": \"huacabala@gmail.com\", \"subject2\": \"Recuperación de contraseña\", \"type2\": 3, \"template2\": \"recovery_password\", \"parameters2\": {\"baseUrl2\": \"https://centrodemonitoreo.rimac.com\", \"url2\": \"https://centrodemonitoreo.rimac.com/recovery/UhL4I_flA\", \"email2\": \"huacabala@gmail.com\", \"extraParam12\": \"Additional info that needs to be processed carefully.\", \"extraParam22\": \"Some more extra information to extend the length.\", \"extraParam32\": \"https://example.com/extended_url_part3\"}}, \"response2\": {\"mailId2\": 9978954, \"code2\": 200, \"body2\": {\"message2\": \"CORREO ENVIADO - 010001923504b86c-613bbc9c-4251-44de-8f3e-f092f81e086c-000000\", \"log2\": \"Additional response details with more metadata.\", \"additionalInfo2\": \"This message was sent successfully using a secure mail service with timestamp validation.\", \"details2\": \"Unique details about the transaction that occurred during the operation.\", \"trackingId2\": \"TRACKER-8292929292929\", \"uuid2\": \"c29a92a1-4452-4a58-9f92-7296f62e623b\"}, \"message2\": \"CONSULTA TERMINADA\", \"debugInfo2\": {\"step12\": \"Initialization completed successfully.\", \"step22\": \"Mail service authenticated.\", \"step32\": \"Mail composed and sent.\", \"step42\": \"Response validated and returned.\", \"fullLog2\": \"This full log contains the trace for each step during the mail recovery process with additional checks.\"}}, \"status2\": \"unique\", \"name2\": \"mail\", \"action2\": \"send\", \"traceId2\": \"672c26ff-7d3d-4cd1-9a94-0c3e239f17a12\", \"resource2\": \"UE2COMPRODLMBCMOPUBLIC\", \"createdAt2\": \"2024-09-27T19:45:54.937Z\", \"additionalData2\": {\"dataSet12\": \"This is an extended data set that contains more information for further processing.\", \"dataSet22\": \"More tracking information for the system to process under certain conditions.\", \"dataSet32\": \"https://longer.example.com/more_data_for_extending_the_json_structure_part3\", \"meta2\": {\"id2\": 1234567890, \"description2\": \"A detailed description about the metadata involved in the request/response cycle.\", \"tags2\": [\"tag12\", \"tag22\", \"tag32\", \"tag42\"], \"type2\": \"secure\", \"trace2\": \"Execution trace with extra debugging information to ensure validity.\"}}}";

  // Convertir el texto JSON en un objeto JavaScript
  const jsonObject = JSON.parse(texto);

  //Impresion de log en consola, Instana reconoce de manera automatica los logs con severidad warning y error.
  console.error(JSON.stringify(jsonObject, null, 2));


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

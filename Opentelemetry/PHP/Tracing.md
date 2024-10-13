## Aplicacion Demo en Windows Server

## Prerequisitos

1. Instalar php 8.2+ Zip [Instalador](https://windows.php.net/download/)
2. Instalar composer [Instalador](https://getcomposer.org/download/)
3. Instalar dependencias Opentelemetry [Procedimiento](#instalar-dependencias-opentelemetry)
4. Despliegue de agente Instana ([Instalación](https://github.com/juan-conde-21/Instalacion-Agente-Instana/blob/main/README.md)) con el sensor de opentelemetry activo ([Procedimiento](https://github.com/juan-conde-21/Instalacion-Agente-Instana/blob/main/Sensores/Opentelemetry.md)).
5. Instalar git para la descarga de las dependencias. [Instalador](https://git-scm.com/downloads/win)

## Instalar dependencias Opentelemetry 

1. Instalar extension de Openteletemetry para PHP y colocar en la ruta de extensiones. (C:\php\ext)

    Descargar extension de opentelemetry desde pecl opentelemetry [Descargar](https://pecl.php.net/package/opentelemetry)

    Activar la extension de opentelemetry en el archivo php.ini, colocar lo siguiente:
   
       extension=opentelemetry

2. Instalar extension para grpc.

   Descargar de pecl grpc y colocar en la ruta de extensiones. (C:\php\ext) [Descargar](https://pecl.php.net/package/gRPC)

   Activar la extension de grpc en el archivo php.ini, colocar lo siguiente:
   
       extension=grpc

3. Configurar las variables de entorno en el archivo php.ini y reiniciar el servicio.

   php.ini

       [opentelemetry]
       OTEL_PHP_AUTOLOAD_ENABLED='true'
       OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
       OTEL_EXPORTER_OTLP_PROTOCOL=grpc
       OTEL_SERVICE_NAME=webphp

4. Reiniciar PHP.


## Despliegue de la Aplicación

Se trabajara en base a la aplicacion demo para PHP de Opentelemetry ([Documentación](https://opentelemetry.io/docs/languages/php/getting-started/)), con la instrumentación automática.

1. Crear la carpeta de la app.

2. Instalar librerias requeridas mediante composer.

       composer init --no-interaction --require slim/slim:"^4" --require slim/psr7:"^1"
       composer update

3. Instalar el SDK para PHP dependiendo del framework utilizado, para este ejemplo se utiliza slim.

       composer require open-telemetry/sdk open-telemetry/opentelemetry-auto-slim
       composer require open-telemetry/exporter-otlp

4. Instalar dependencias de acuerdo al protocolo a utilizar otlp o grpc.

   ***Dependencias para OTLP***

       composer require open-telemetry/exporter-otlp
       composer require php-http/guzzle7-adapter

   ***Dependencias para GRPC***

       composer require open-telemetry/transport-grpc

5. Dentro de la carpeta crear el archivo index.php y agregar el siguiente contenido. Luego guardar y salir del archivo.

       <?php
       use Psr\Http\Message\ResponseInterface as Response;
       use Psr\Http\Message\ServerRequestInterface as Request;
       use Slim\Factory\AppFactory;
        
       require __DIR__ . '/vendor/autoload.php';
        
       $app = AppFactory::create();
        
       $app->get('/rolldice', function (Request $request, Response $response) {
           $result = random_int(1,6);
           $response->getBody()->write(strval($result));
           return $response;
       });
        
       $app->run();

6. Se puede colocar las variables de entorno de opentelemetry directamente en la linea de comandos. (Opcional)
   
       set OTEL_PHP_AUTOLOAD_ENABLED=true
       set OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
       set OTEL_EXPORTER_OTLP_PROTOCOL=grpc
       set OTEL_SERVICE_NAME=webphp

7. Ejecutar la aplicacion.

       php -S localhost:8080

   ![image](https://github.com/user-attachments/assets/6d72b890-5640-4202-b3e2-baf74edab66c)

8. Revisar en la consola de Instana el envio de las trazas.

   ![image](https://github.com/user-attachments/assets/dac40d69-dc7e-4f34-8e45-b636a4bd4d46)






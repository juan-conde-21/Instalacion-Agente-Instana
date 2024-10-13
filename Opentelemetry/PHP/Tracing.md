## Aplicacion Demo en Windows Server

## Prerequisitos

1. Instalar php 8.2+ Zip [Instalador](https://windows.php.net/download/)
2. Instalar composer [Instalador](https://getcomposer.org/download/)
3. Instalar dependencias Opentelemetry 

## Instalar dependencias Opentelemetry 

1. Instalar extension de Openteletemetry para PHP y colocar en la ruta de extensiones. (C:\php\ext)

    Descargar extension de opentelemetry desde pecl opentelemetry [Descargar](https://pecl.php.net/package/opentelemetry)

    Activar la extension de opentelemetry en el archivo php.ini, colocar lo siguiente:
   
       extension=opentelemetry

3. Instalar librerias requeridas mediante composer.

       composer init --no-interaction --require slim/slim:"^4" --require slim/psr7:"^1"
       composer update

4. Instalar librerias de Opentelemetry SDK para PHP. (Depende del framework utilizado en PHP, para este ejemplo se utiliza slim)

       composer require open-telemetry/sdk open-telemetry/opentelemetry-auto-slim
       composer require open-telemetry/exporter-otlp

   ***Dependencias para GRPC***

   Descargar de pecl grpc y colocar en la ruta de extensiones. (C:\php\ext) [Descargar](https://pecl.php.net/package/gRPC)

       composer require open-telemetry/transport-grpc

   Activar la extension de grpc en el archivo php.ini, colocar lo siguiente:
   
       extension=grpc

   ***Dependencias para OTLP***

       composer require open-telemetry/exporter-otlp
       composer require php-http/guzzle7-adapter

5. Configurar las variables de entorno en el archivo php.ini y reiniciar el servicio.

   php.ini

       [opentelemetry]
       OTEL_PHP_AUTOLOAD_ENABLED='true'
       OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
       OTEL_EXPORTER_OTLP_PROTOCOL=grpc
       OTEL_SERVICE_NAME=webphp

   Tambien se pueden colocar como variables de entorno

       set OTEL_PHP_AUTOLOAD_ENABLED=true
       set OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
       set OTEL_EXPORTER_OTLP_PROTOCOL=grpc
       set OTEL_SERVICE_NAME=webphp

6. Reiniciar PHP.


## Despliegue de la Aplicación

1. Crear la carpeta de la app.





php -S localhost:8080

# Configuración de la Integracion con Telegram


## Prerrequisitos

1. Realizar el registro de un bot en Telegram que estará asociado al grupo a notificar.
2. Obtener el Bot token y chat ID del grupo a notificar los eventos de Instana.


## Procedimiento

1. Desplegar contenedor con servidor webhook para el envío a Telegram. 

   Ejecución de Contenedor

   docker run -e TELEGRAM_BOT_TOKEN=7902262951:AAF5DMxiMBR8TdSiicDzF4-4MopKgK5qwEA -e TELEGRAM_CHAT_ID=-4796946695 -dt -p 5000:5000 juanconde24/instana-telegram-webhook:v2










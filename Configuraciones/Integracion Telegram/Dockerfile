# Usa una imagen base oficial de Python
FROM python:3.9-slim

# Establece el directorio de trabajo en /app
WORKDIR /app

# Copia el archivo de requisitos a la imagen
COPY requirements.txt requirements.txt

# Instala las dependencias necesarias
RUN pip install -r requirements.txt

# Copia el resto del código de la aplicación a la imagen
COPY . .

# Define las variables de entorno
ENV TELEGRAM_BOT_TOKEN=""
ENV TELEGRAM_CHAT_ID=""

# Expone el puerto en el que correrá la aplicación
EXPOSE 5000

# Define el comando de arranque de la aplicación
CMD ["python", "app.py"]

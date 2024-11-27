# Habilitación de Sensor SAP ABAP

## Prerrequisitos:

1. Tener instalado el agente Instana.
2. Descargar la librería JCo 3.1.8 o superior en el servidor con agente Instana. ([Descargar](https://support.sap.com/en/product/connectors/jco.html))
3. Ubicar la ruta de instalación del agente Instana de acuerdo con la plataforma:

   Windows

       C:\Program Files\Instana\instana-agent\

   Linux

       /opt/instana/agent/

   Unix

       /opt/instana-agent/

4. Crear el siguiente subdirectorio dentro de la ruta de instalación del agente Instana localizado en el punto anterior.

   /com/sap/sapjco3/<Major>.<Minor>.<patch>

   *La referencia al valor de "<Major>.<Minor>.<patch>" corresponde con la versión de la librería JCo descargada, ejemplo para la versión 3.1.8 el subdirectorio creado será el siguiente:

   /com/sap/sapjco3/3.1.8

   Ejemplo directorio completo en Linux:

   /opt/instana/agent/com/sap/sapjco3/3.1.8

5. Extraer el contenido de la librería JCo descargada en el punto 2 dentro del nuevo subdirectorio creado.

6. Renonmbrar el archivo sapjco3.jar agregando la version de la librería JCo descargada sapjco3-<Major>.<Minor>.<patch>.jar

   Ejemplo de archivo renombrado:

   sapjco3-3.1.8.jar

7. Colocar el archivo de la biblioteca específica del sistema operativo en el directorio creado en el punto 4, La extensión del archivo puede ser .dll o .so de acuerdo con la plataforma de la biblioteca descargada.

   Ejemplo en Linux:

   /opt/instana/agent/system/com/sap/sapjco3/3.1.8/libsapjco3.so

8. Verificar que ambos archivos de la librería SAP JCo se encuentren correctamente configurados.

   Ejemplo en Linux:

   ls /opt/instana/agent/system/com/sap/sapjco3/3.1.8/
   libsapjco3.so  sapjco3-3.1.8.jar


## Configuración de Sensor

1. Ingresar al archivo de configuración del agente Instana

   Windows

       C:\Program Files\Instana\instana-agent\etc\instana

   Linux

       /opt/instana/agent/etc/instana/

   Unix

       /opt/instana-agent/etc/instana/

3. Ubicar las lineas para el sensor SAP en el archivo de configuracion.

       vi configuration.yaml

   ![image](https://github.com/user-attachments/assets/e34b0db7-3cda-424e-b250-4990e2d70743)

4. Descomentar las lineas del sensor SAP y realizar las modificaciones de acuerdo con el ambiente a configurar.

   

5. Guardar los cambios y verificar que el cluster IBM DataPower se encuentre reportando.

   En el módulo Infrastructure ubicar el detalle de los componentes de Infraestructura, luego ubicar los componentes de DataPower descubiertos:


   Se mostrara el clúster descubierto: Filtrar por "entity.type:ibmDataPower.cluster"

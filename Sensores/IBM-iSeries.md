# Habilitación de Sensor IBM iSeries

## Prerrequisitos:

1. IBM i 7.2 y versiones posteriores.
2. Agente Instana desplegado([Instalación](https://github.com/juan-conde-21/Instalacion-Agente-Instana/blob/main/README.md))
3. El usuario QSECOFR es requerido para la configuración y conexión del agente al sistema operativo y la base de datos DB2 iSeries.
4. Verificar la conectividad habilitada a los siguientes puertos desde el Host donde se desplego el Agente Instana hacia el servidor IBM i.

   - 8470: Traducción de páginas de código y funciones de licencias.
   - 8471: Acceso a la base de datos.
   - 8475: Restricciones de administración de aplicaciones.
   - 8476: Verificación de inicio de sesión y autenticación.
   - 449: Búsqueda de servicios por nombre y retorno del número de puerto.
   - 446: Gestión de datos distribuidos (DDM/DRDA) para conexiones remotas a Db2 for IBM i.
   - 1415: Control de sesión DDM.
   - 1416: Gestión de mensajes de control.
   - 1417: Transferencia de datos DDM.
   - 1418: Comunicación SQL/DRDA.
   - 1419: Gestión de datos de diagnóstico o sesiones adicionales.

5. Configurar Performance Collection en IBM iSeries, ejecutar comando “CFGPFRCOL”, y modificar los siguientes parámetros:

       INTERVAL(00.50)
       LIB(QPFRDATA)
       DFTCOLPRF(*STANDARD) 
       CYCTIME(000000)
       CYCITV(01)
       RETPERIOD(00001 *HOURS)
       ENBSYSMON(*YES)
       CRTDBF(*YES)
       CRTPFRSUM(*NONE)
       SYSMONCGY(*SYSMONDFT)

6. Iniciar el Performance Collection, ejecutar comando “STRPFRCOL” y modificar los siguientes parámetros:

       COLPRF(*CFG)
       CYCCOL(*YES)


7. Validar tener estos componentes del performance tools:

   - Tenemos Performance Tools – Gestor
   - Performance Tools – Observador de trabajos

 8. Validar si el performance tool tiene los ultimos PTF instalados.


## Configuración de Sensor

1. Ingresar al archivo de configuración del agente Instana

   Windows

       C:\Program Files\Instana\instana-agent\etc\instana

   Linux

       /opt/instana/agent/etc/instana/

2. Ubicar las lineas para el sensor de IBM iSeries en el archivo de configuracion.

       vi configuration.yaml

   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/935b5ea0-b534-41f0-9006-bb21ae967059)

   Configuración de ejemplo:

       # IBM i Series
       com.instana.plugin.ibmiseries:
         enabled: true
         remote: # multiple configurations supported
           - host: 'remote.host-1.com'
              #For a SSL connection set sslEnabled to either true or false.
       #      sslEnabled: 'true/false'
             user: 'username'
             password: 'password'
             availabilityZone: 'IBM i Remote Monitoring'
             poll_rate: 15 # seconds


3. Guardar los cambios y verificar que el servidor iSeries se encuentre reportando en Instana.

   En el módulo de infraestructura:

   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/8d369920-ef78-4200-b49d-a58384d5c768)

   Filtrar por Sistema operativo: entity.selfType:ibmi.os

   ![image](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/717d752c-5129-42bf-9731-5038f0795337)





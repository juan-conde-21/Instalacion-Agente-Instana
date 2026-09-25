# Habilitación de Sensor IBM iSeries

Este procedimiento considera el monitoreo remoto de IBM i desde un agente Instana desplegado en Windows o Linux.

## Prerrequisitos

1. IBM i 7.3 o superior para monitoreo remoto.

2. Agente Instana desplegado ([Instalación](https://github.com/juan-conde-21/Instalacion-Agente-Instana/blob/main/README.md)).

3. Crear o utilizar un usuario dedicado para Instana.

   No es necesario utilizar `QSECOFR`. El usuario configurado en Instana debe contar con las siguientes autoridades:

   - Autoridad especial `*JOBCTL`.
   - `*USE` sobre `QSYS/CHKPFRCOL`.
   - `*USE` sobre `QSYS/WRKPTFGRP`.
   - `*USE` sobre la lista de autorizaciones `QPMCCDATA`.
   - `*ALL` sobre `QSYS/QAUDJRN`.
   - `*USE` sobre los journal receivers asociados a `QAUDJRN`.

   Validar:

        DSPUSRPRF USRPRF(INSTANA)
        DSPAUTL AUTL(QPMCCDATA)
        DSPOBJAUT OBJ(QSYS/CHKPFRCOL) OBJTYPE(*CMD)
        DSPOBJAUT OBJ(QSYS/WRKPTFGRP) OBJTYPE(*CMD)
        DSPOBJAUT OBJ(QSYS/QAUDJRN) OBJTYPE(*JRN)

   Ejemplo para los journal receivers:

        GRTOBJAUT OBJ(QGPL/AUDRCV*) OBJTYPE(*JRNRCV) USER(INSTANA) AUT(*USE)

   > Para IBM i 7.6, el usuario utilizado para monitoreo remoto no debe requerir MFA/TOTP.

4. Verificar conectividad desde el host donde se encuentra el agente Instana hacia IBM i.

   Puertos utilizados por el sensor:

   - `449`: Server Mapper.
   - `446`: DDM/DRDA.
   - `8470`: funciones de licencia y traducción.
   - `8471`: acceso a base de datos.
   - `8475`: Remote Command / Application Administration.
   - `8476`: autenticación.

   > Si se utiliza SSL/TLS, validar también la configuración de puertos seguros y certificados del IBM i.

## Configuración de Collection Services

Instana utiliza Collection Services para obtener métricas de rendimiento y datos de Db2.

1. Ejecutar:

        CFGPFRCOL

2. Presionar `F4` y validar la configuración.

   Configuración recomendada como punto de partida:

        INTERVAL(5.00)
        LIB(QPFRDATA)
        DFTCOLPRF(*STANDARDP)
        CYCTIME(000000)
        CYCITV(24)
        RETPERIOD(00072 *HOURS)
        ENBSYSMON(*YES)
        CRTDBF(*YES)

   Consideraciones:

   - `INTERVAL(5.00)` corresponde a 5 minutos.
   - `*STANDARD` y `*STANDARDP` incluyen la categoría `*SQL` utilizada por Instana para Db2.
   - `CRTDBF(*YES)` permite crear los archivos estándar `QAPM*` utilizados para consultar los datos recolectados.
   - La retención puede ajustarse según el espacio disponible. `72 HOURS` mantiene tres días de colecciones `*MGTCOL`.

3. Iniciar o ciclar Collection Services:

        STRPFRCOL COLPRF(*CFG) CYCCOL(*YES)

4. Validar el estado:

        CHKPFRCOL

   Sobre el mensaje de Collection Services activo, presionar `F1` y confirmar:

   - Biblioteca de colección: `QPFRDATA`.
   - Perfil activo: `*STANDARDP` o `*STANDARD`.
   - Objeto de colección activo `*MGTCOL`.

5. Validar la creación del archivo utilizado para métricas SQL:

        DSPOBJD OBJ(QPFRDATA/QAPMSQLPC) OBJTYPE(*FILE)

   > Si se modificó el perfil o `CRTDBF`, realizar un nuevo ciclo de Collection Services antes de validar nuevamente.

## Configuración del Sensor

1. Ingresar al archivo de configuración del agente Instana.

   Windows:

        C:\Program Files\Instana\instana-agent\etc\instana\configuration.yaml

   Linux:

        /opt/instana/agent/etc/instana/configuration.yaml

2. Agregar la configuración para monitoreo remoto de IBM i.

   ![Configuración del sensor IBM iSeries en configuration.yaml](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/935b5ea0-b534-41f0-9006-bb21ae967059)

        # IBM i Series
        com.instana.plugin.ibmiseries:
          enabled: true
          remote:
            - host: 'remote.host.com'
              sslEnabled: false
              user: 'INSTANA'
              password: 'password'
              availabilityZone: 'IBM i Remote Monitoring'
              poll_rate_configuration:
                os_poll_rate: 15
                db2_poll_rate: 15

   `os_poll_rate` y `db2_poll_rate` se expresan en segundos.

   Si se configura `sslEnabled: true`, importar el certificado de confianza en el `cacerts` del JRE utilizado por el agente.

3. Guardar los cambios y validar que el servidor IBM i se encuentre reportando en Instana.

   En el módulo de infraestructura:

   ![Servidor IBM i reportando en Infraestructura](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/8d369920-ef78-4200-b49d-a58384d5c768)

   Filtrar por sistema operativo:

        entity.selfType:ibmi.os

   ![Filtro de IBM i en Infraestructura](https://github.com/juan-conde-21/Instalacion-Agente-Instana/assets/13276404/717d752c-5129-42bf-9731-5038f0795337)

## Troubleshooting

### QAPMSQLPC no existe

Error típico:

    CPF3012 - No se ha encontrado el archivo QAPMSQLPC en la biblioteca QPFRDATA

Validar:

    CFGPFRCOL

Confirmar:

    DFTCOLPRF(*STANDARDP)
    CRTDBF(*YES)

Aplicar un nuevo ciclo:

    STRPFRCOL COLPRF(*CFG) CYCCOL(*YES)

Luego validar:

    DSPOBJD OBJ(QPFRDATA/QAPMSQLPC) OBJTYPE(*FILE)

#### Posible caso: generar únicamente la categoría SQL

Si Collection Services está activo pero `QAPMSQLPC` no se genera, identificar el `*MGTCOL` activo con `CHKPFRCOL` y probar:

    CRTPFRDTA FROMMGTCOL(QPFRDATA/<MGTCOL>) TOLIB(QPFRDATA) CGY(*SQL)

Luego validar nuevamente:

    DSPOBJD OBJ(QPFRDATA/QAPMSQLPC) OBJTYPE(*FILE)

> Utilizar esta ejecución manual como validación/troubleshooting. Con `CRTDBF(*YES)`, la generación de los archivos estándar debe quedar automatizada en los siguientes ciclos.

### Posible caso: QAPMSQLPC existe pero Instana no puede leerlo

Error típico:

    CPF3026 - No tiene autorización al archivo QAPMSQLPC en la biblioteca QPFRDATA

Validar:

    DSPAUTL AUTL(QPMCCDATA)
    DSPOBJAUT OBJ(QPFRDATA/QAPMSQLPC) OBJTYPE(*FILE)
    DSPOBJAUT OBJ(QPFRDATA) OBJTYPE(*LIB)

El usuario configurado en Instana debe tener acceso de lectura al archivo y acceso a la biblioteca.

Si el archivo fue generado manualmente y quedó con autoridades diferentes, validar con el administrador IBM i antes de otorgar acceso directo:

    GRTOBJAUT OBJ(QPFRDATA/QAPMSQLPC) OBJTYPE(*FILE) USER(INSTANA) AUT(*USE)

### Posible caso: SQL0666

Error típico:

    SQL0666 - La consulta SQL excede el límite o el umbral especificado

Este error puede afectar consultas realizadas por Instana sobre servicios `QSYS2`.

Validar con el administrador IBM i:

    DSPSYSVAL SYSVAL(QQRYTIMLMT)

Revisar también límites configurados mediante Query Governor, `CHGQRYA`, `QAQQINI` o Query Supervisor. No modificar límites globales sin validación previa.

### Sensor se activa y desactiva continuamente

Si aparecen mensajes como:

    Activated Sensor
    Removing sensor for host
    Deactivated Sensor

Revisar primero el error que aparece inmediatamente antes de `Removing sensor for host`. Los errores de conexión, `InterruptedException` o fallas posteriores pueden ser consecuencia de la desactivación del sensor y no necesariamente la causa inicial.

## Notas

- La documentación actual de Instana soporta monitoreo remoto desde IBM i 7.3 y monitoreo local desde IBM i 7.4.
- Para Db2 for IBM i, IBM indica que la categoría `*SQL` debe estar incluida en Collection Services.
- La documentación de Db2 for IBM i indica soporte de locale en inglés; otros idiomas pueden presentar limitaciones en parsing o configuración.
- Performance Tools / Job Watcher pueden ser útiles para diagnóstico, pero no se consideran un requisito base del sensor IBM i de Instana.

## Referencias

- [IBM Instana - Monitoring IBM i instances](https://www.ibm.com/docs/en/instana-observability?topic=technologies-monitoring-i-instances)
- [IBM Instana - Monitoring Db2 for IBM i](https://www.ibm.com/docs/en/instana-observability?topic=technologies-monitoring-db2-i)
- [IBM i - Configure Performance Collection (CFGPFRCOL)](https://www.ibm.com/docs/en/i/7.5.0?topic=ssw_ibm_i_75%2Fcl%2Fcfgpfrcol.html)

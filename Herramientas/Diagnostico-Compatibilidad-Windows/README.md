# Diagnóstico de compatibilidad de IBM Instana para Windows

Esta herramienta recopila evidencia técnica de un servidor Windows y evalúa la compatibilidad de las tecnologías detectadas con IBM Instana.

El objetivo es facilitar una validación inicial de compatibilidad antes de una instalación, prueba de concepto o revisión técnica, sin modificar la configuración del servidor.

> El resultado corresponde a una evaluación automatizada basada en la matriz de soporte incorporada en el script. Para decisiones de producción o casos no concluyentes, se debe contrastar el resultado con la documentación oficial vigente de IBM Instana.

---

## Alcance

El script valida:

- Sistema operativo Windows Server y arquitectura.
- Versión de PowerShell disponible.
- Microsoft IIS.
- Sitios, aplicaciones y Application Pools de IIS.
- CLR configurado en los Application Pools.
- Aplicaciones .NET Framework hospedadas en IIS.
- Aplicaciones .NET y .NET Core hospedadas en IIS.
- Versiones de .NET Framework instaladas.
- Runtimes de .NET instalados.
- Microsoft SQL Server instalado localmente, cuando existe.
- Evidencia de versión encontrada en `web.config`, `runtimeconfig.json` y ensamblados.

El script **no valida**:

- Instalación o estado del agente de Instana.
- Configuración del agente.
- Instrumentación efectiva de las aplicaciones.
- Profiler, sensores o generación de trazas.
- Conectividad con el backend de Instana.
- Credenciales, tokens o llaves.
- Aplicaciones .NET ejecutadas como servicios Windows independientes de IIS.
- Compatibilidad detallada de cada librería utilizada por la aplicación.
- Azure App Service u otras plataformas PaaS.

---

## Seguridad

El script es de solo lectura:

- No instala componentes.
- No reinicia IIS ni servicios.
- No modifica Application Pools.
- No modifica el registro de Windows.
- No cambia políticas permanentes de PowerShell.
- No copia archivos `web.config` completos.
- No extrae connection strings, contraseñas o certificados.
- No requiere que el agente de Instana esté instalado.
- No requiere acceso a Internet.

La información recopilada se guarda en archivos CSV y TXT dentro de un ZIP generado al finalizar.

---

## Requisitos de ejecución

- Windows Server 2012 o posterior.
- Windows PowerShell 3.0 o posterior.
- Permisos de administrador recomendados para obtener evidencia completa.
- Permiso de lectura sobre la configuración de IIS y las rutas físicas de las aplicaciones.

El script puede ejecutarse sin privilegios administrativos, pero algunas secciones podrían quedar como evidencia parcial.

---

## Archivos de la carpeta

```text
Diagnostico-Compatibilidad-Windows/
├── Diagnostico-Compatibilidad-Instana-Windows.ps1
└── README.md
```

---

## Cómo descargar y ejecutar

### 1. Descargar el contenido

Se puede descargar el repositorio completo mediante:

```text
Code > Download ZIP
```

También se puede descargar únicamente esta carpeta desde GitHub mediante la herramienta o método autorizado por la organización.

### 2. Descomprimir

Seleccionar **Extraer todo** y descomprimir el contenido en cualquier carpeta local donde el usuario tenga permisos de escritura.

No es necesario utilizar una ruta específica como `C:\Temp`.

### 3. Abrir PowerShell desde la carpeta

Abrir la carpeta donde se encuentra el archivo:

```text
Diagnostico-Compatibilidad-Instana-Windows.ps1
```

Hacer clic en la barra de direcciones del Explorador de archivos, escribir:

```text
powershell
```

Presionar **Enter**.

PowerShell se abrirá ubicado directamente en esa carpeta.

### 4. Ejecutar el diagnóstico

Ejecutar los siguientes comandos uno por uno:

```powershell
$Script = (Resolve-Path ".\Diagnostico-Compatibilidad-Instana-Windows.ps1").Path
```

```powershell
Unblock-File -Path $Script
```

```powershell
Start-Process powershell.exe -Verb RunAs -Wait -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$Script`" -MantenerVentanaAbierta"
```

Windows solicitará autorización para abrir una consola con permisos de administrador. Seleccionar **Sí**.

`ExecutionPolicy Bypass` se aplica únicamente a esa ejecución y no modifica permanentemente la política de PowerShell del servidor.

---

## Comportamiento durante la ejecución

Se abrirá una segunda ventana de PowerShell con permisos elevados.

El script:

1. Recopila la información del servidor.
2. Identifica IIS y sus aplicaciones.
3. Detecta los runtimes .NET disponibles.
4. Evalúa la compatibilidad de cada tecnología encontrada.
5. Genera archivos de evidencia.
6. Consolida los resultados en un ZIP.
7. Muestra un resumen ejecutivo en pantalla.

La consola permanecerá abierta al finalizar y mostrará:

```text
Presione ENTER para finalizar
```

Esto permite revisar el resultado y copiar la ruta del ZIP antes de cerrar la ventana.

---

## Resultado generado

El ZIP se crea, de preferencia, en la misma carpeta donde se encuentra el script:

```text
Instana-Compatibilidad-NOMBRE-SERVIDOR-AAAAMMDD-HHMMSS.zip
```

Si la carpeta no permite escritura, el script utiliza la carpeta temporal definida por Windows y muestra la ruta completa en consola.

El cliente debe compartir únicamente el archivo ZIP generado.

---

## Contenido del ZIP

| Archivo | Descripción |
|---|---|
| `00-Resumen-Compatibilidad.txt` | Resultado ejecutivo y evaluación por aplicación. |
| `01-Sistema.csv` | Sistema operativo, arquitectura, CPU, memoria y PowerShell. |
| `02-Prerequisitos.csv` | Información de capacidad utilizada como contexto. |
| `03-IIS-Version.csv` | Presencia y versión de IIS. |
| `04-IIS-ApplicationPools.csv` | Pools, CLR, pipeline, arquitectura y estado. |
| `05-IIS-Sitios.csv` | Sitios y bindings encontrados. |
| `06-IIS-Aplicaciones.csv` | Relación entre aplicaciones, pools y rutas físicas. |
| `07-DotNet-Framework.csv` | Versiones de .NET Framework instaladas. |
| `08-DotNet-Runtimes.csv` | Runtimes .NET instalados y clasificación. |
| `09-Aplicaciones-Evidencia-Runtime.csv` | Indicadores de runtime encontrados por aplicación. |
| `10-SQL-Server.csv` | Instancias locales de SQL Server y versión detectada. |
| `11-Evaluacion-Aplicaciones.csv` | Resultado técnico y orientado al cliente por aplicación. |
| `12-Matriz-Tecnologias.csv` | Matriz consolidada de tecnologías evaluadas. |
| `99-Errores.csv` | Secciones que no pudieron recopilarse completamente. |

---

## Interpretación del resultado

### FAVORABLE

Las tecnologías detectadas se encuentran dentro de los criterios de soporte incorporados.

### FAVORABLE CON RECOMENDACIONES

La compatibilidad es favorable, pero se identificó una recomendación de ciclo de vida, configuración o modernización.

### FAVORABLE CON OBSERVACIONES

La plataforma base es compatible, pero existe evidencia parcial, una limitación documentada o una aplicación que requiere análisis adicional.

Una observación sobre una aplicación no invalida automáticamente la compatibilidad del servidor completo.

### REQUIERE REVISIÓN TÉCNICA

La evidencia no permite una conclusión automática o la plataforma base no coincide con los criterios incorporados. Este resultado debe revisarse con un especialista y contrastarse con la documentación oficial.

---

## Casos que no deben interpretarse como incompatibilidad

- Una ruta de aplicación no pudo ser leída.
- No se detectó IIS.
- No existe SQL Server instalado localmente.
- No se encontraron aplicaciones .NET en IIS.
- El runtime exacto no pudo determinarse.
- Se encontró una tecnología con soporte deprecado.
- La aplicación utiliza una configuración con limitaciones documentadas.

En estos casos el script registra `NO APLICA`, `EVIDENCIA PARCIAL`, una recomendación o una revisión técnica, según corresponda.

---

## Referencias oficiales

- [Prerequisitos del agente Instana en Windows](https://www.ibm.com/docs/en/instana-observability?topic=windows-checking-agent-prerequisites)
- [Monitoreo de aplicaciones .NET y .NET Core](https://www.ibm.com/docs/en/instana-observability?topic=technologies-monitoring-net-net-core)
- [Información de soporte para .NET](https://www.ibm.com/docs/en/instana-observability?topic=core-support-information)
- [Monitoreo de Microsoft SQL Server](https://www.ibm.com/docs/en/instana-observability?topic=technologies-monitoring-microsoft-sql-server)

---

## Mantenimiento de la matriz

La fecha de la matriz de soporte incorporada se encuentra declarada dentro del script mediante:

```powershell
$SupportMatrixDate
```

Antes de utilizar la herramienta en una evaluación formal, se recomienda comprobar que los criterios continúan alineados con la documentación oficial vigente.

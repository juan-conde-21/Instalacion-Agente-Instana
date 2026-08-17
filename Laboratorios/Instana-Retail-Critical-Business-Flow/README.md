# Instana - Flujo crítico de negocio Retail

Laboratorio reproducible para demostrar cómo **IBM Instana** puede identificar impacto real sobre un proceso de negocio aun cuando la infraestructura y la aplicación continúan técnicamente disponibles.

> Este laboratorio forma parte del repositorio:
> `juan-conde-21/Instalacion-Agente-Instana`

## Resumen ejecutivo

El escenario simula un proceso que depende de la generación, distribución y consumo de un archivo crítico de promociones.

```text
SOURCE -> CENTRAL -> RETAIL -> BUSINESS
```

En operación normal, el archivo se genera y distribuye correctamente y la transacción de negocio responde `SUCCESS`.

Durante la falla controlada:

- SOURCE continúa generando información.
- CENTRAL continúa respondiendo `HTTP 200`.
- RETAIL continúa respondiendo `HTTP 200`.
- El archivo crítico deja de actualizarse.
- El archivo supera su antigüedad permitida y queda `STALE`.
- La operación de negocio falla con `HTTP 503`.

El objetivo es evidenciar que **disponibilidad técnica no siempre equivale a disponibilidad del negocio**.

Instana permite correlacionar este escenario mediante APM, logs, File Monitoring, Synthetic Monitoring, alertas, SLO y dashboards.

---

## Arquitectura lógica

```text
                    IBM INSTANA
        APM + Logs + File Monitoring + Synthetic
              Smart Alert + SLO + Dashboard
                         |
                         v

SOURCE --------> CENTRAL --------> RETAIL --------> BUSINESS
Bastion           Bluebox          Demo Apps
```

### Componentes

| Componente | Función |
|---|---|
| Bastion | Nodo de control, SOURCE y automatización |
| Bluebox | Servicio CENTRAL, Instana Agent, File Monitoring y OTel |
| Demo Apps | K3s, aplicación RETAIL, OTel, Instana K8Sensor y Synthetic Private PoP |
| Instana | APM, logs, Synthetic, alertas, SLO y dashboard |

Las direcciones, endpoints y credenciales deben adaptarse al ambiente donde se despliegue.

---

# Inicio rápido desde GitHub

## 1. Clonar el repositorio

En el servidor Bastion:

```bash
cd /opt

git clone https://github.com/juan-conde-21/Instalacion-Agente-Instana.git

cd /opt/Instalacion-Agente-Instana/Laboratorios/Instana-Retail-Critical-Business-Flow
```

Si el repositorio ya existe:

```bash
cd /opt/Instalacion-Agente-Instana
git pull origin main

cd Laboratorios/Instana-Retail-Critical-Business-Flow
```

La ubicación del laboratorio dentro del repositorio es:

```text
Instalacion-Agente-Instana/
└── Laboratorios/
    └── Instana-Retail-Critical-Business-Flow/
```

---

## 2. Estructura del laboratorio

```text
Instana-Retail-Critical-Business-Flow/
├── README.md
├── instana-api/
│   ├── 00-load-instana-env.sh
│   ├── 00-load-lab-env.sh
│   ├── 00-load-runtime-env.sh
│   ├── 01-create-application.sh
│   ├── 02-sync-synthetics.sh
│   ├── 03-create-synthetic-alert.sh
│   ├── 04-create-slo.sh
│   ├── 04b-create-technical-slo.sh
│   ├── 05-create-dashboard-base.sh
│   ├── 05-create-dashboard.sh
│   ├── 05b-add-apm-widgets.sh
│   ├── 06-demo-status.sh
│   ├── 07-demo-fault.sh
│   ├── 08-demo-observe.sh
│   ├── 09-demo-recover.sh
│   ├── 10-demo-runbook.sh
│   ├── 11-golden-snapshot.sh
│   ├── 12-setup-secrets.sh
│   ├── 13-precheck-all.sh
│   ├── 14-inventory-before-cleanup.sh
│   ├── 15-cleanup-instana.sh
│   ├── 16-validate-clean-state.sh
│   ├── 17-rebuild-instana.sh
│   └── config/
├── orchestration/
│   ├── 00-precheck.sh
│   ├── 20-setup-bastion.sh
│   ├── 30-setup-bluebox.sh
│   ├── 40-check-demoapps.sh
│   ├── 40-setup-demoapps.sh
│   ├── 50-create-instana.sh
│   ├── 60-validate-all.sh
│   ├── install-all.sh
│   └── assets/
│       └── demoapps/
├── demo/
│   └── demo.sh
└── scripts/
    ├── install-from-repo.sh
    └── validate-publication.sh
```

---

# Instalación en Bastion

## 3. Validar el contenido descargado

Desde la carpeta del laboratorio:

```bash
bash scripts/validate-publication.sh
```

La validación comprueba la estructura básica, sintaxis de scripts y presencia accidental de archivos de secretos.

Resultado esperado:

```text
PUBLICATION VALIDATION = PASS
```

---

## 4. Instalar el laboratorio en `/opt/instana-demo`

```bash
sudo bash scripts/install-from-repo.sh
```

El script copia la versión almacenada en GitHub hacia:

```text
/opt/instana-demo/
├── instana-api/
├── orchestration/
└── demo/
```

Los secretos no se copian desde GitHub.

---

## 5. Configurar credenciales locales

Las credenciales deben existir únicamente en el Bastion.

```text
/opt/instana-demo/secrets/instana.token
/opt/instana-demo/secrets/synthetic.env
```

Permisos recomendados:

```bash
sudo chmod 700 /opt/instana-demo/secrets
sudo chmod 600 /opt/instana-demo/secrets/*
```

No almacenar en el repositorio:

- API tokens.
- Download keys.
- Instana keys.
- Redis passwords.
- archivos `.env`.
- logs.
- snapshots Golden.
- archivos de estado generados durante la ejecución.

---

## 6. Precheck

```bash
cd /opt/instana-demo/orchestration

./00-precheck.sh
```

Resultado esperado:

```text
GLOBAL PRECHECK = PASS
```

---

## 7. Instalación integral

```bash
./install-all.sh
```

El flujo automatizado ejecuta:

```text
00  Precheck
20  Bastion / SOURCE
30  Bluebox / CENTRAL + File Monitoring + OTel
40  Demo Apps / RETAIL + OTel
50  Instana as Code
60  Validación End-to-End
```

Resultado esperado:

```text
INSTANA RETAIL LAB = INSTALLATION COMPLETE
```

---

# Ejecución de la demo

```bash
cd /opt/instana-demo/demo
```

## Estado inicial

```bash
./demo.sh status
```

Resultado:

```text
DEMO STATE = HEALTHY
```

## Inyectar falla

```bash
./demo.sh fault
```

## Observar impacto

```bash
./demo.sh observe
```

Durante el escenario se espera:

```text
Central service      : UP
Retail application   : UP
Critical file        : STALE
Business operation   : FAILED
HTTP operation       : 503
```

## Recuperar

```bash
./demo.sh recover
```

## Validar recuperación

```bash
./demo.sh status
```

Resultado:

```text
Critical file        : READY
Business operation   : SUCCESS
HTTP operation       : 200
DEMO STATE           : HEALTHY
```

---

# Qué demuestra el laboratorio

### Estado técnico

```text
CENTRAL HTTP  = 200
RETAIL HTTP   = 200
```

### Estado de negocio durante la falla

```text
Critical File       = STALE
Business Operation  = FAILED
HTTP                 = 503
```

Este contraste permite explicar de forma directa el valor de observabilidad orientada a procesos críticos.

---

# Cobertura de Instana

El laboratorio utiliza:

- Application Perspective.
- APM distribuido.
- Logs vía OpenTelemetry.
- File Monitoring.
- Synthetic Monitoring técnico.
- Synthetic Monitoring de negocio.
- Smart Alert.
- SLO técnico.
- SLO de negocio.
- Custom Dashboard.

---

# Estado actual de automatización

Automatizado:

- SOURCE.
- CENTRAL.
- RETAIL.
- OpenTelemetry.
- File Monitoring.
- objetos lógicos de Instana.
- validación End-to-End.
- inyección y recuperación de falla.

Actualmente se consideran prerrequisitos del ambiente:

- Instana Agent en Bluebox.
- Instana Agent/K8Sensor en Demo Apps.
- K3s.
- Synthetic Private PoP.
- herramientas de compilación requeridas por el laboratorio.

---

# Seguridad

Este repositorio es público. Antes de publicar modificaciones:

```bash
bash scripts/validate-publication.sh
```

No publicar credenciales, claves, tokens, contraseñas, dominios internos ni información propia de ambientes de cliente.

---

## Resultado validado

La secuencia funcional validada es:

```text
HEALTHY
   |
   v
FAULT
   |
   v
FILE STALE
   |
   v
BUSINESS FAILED
   |
   v
RECOVERY
   |
   v
HEALTHY
```

El laboratorio está diseñado para ser repetible y reutilizable en demostraciones, pruebas de concepto y sesiones técnicas de IBM Instana.

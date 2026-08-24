# Arquitectura

## Flujo de negocio

SOURCE genera la información crítica. CENTRAL la distribuye. RETAIL la consume para completar la operación de negocio expuesta por NOVA Market.

SOURCE -> CENTRAL -> RETAIL -> NOVA Market -> CUSTOMER

## Capas observadas

IBM Instana correlaciona:

- disponibilidad técnica;
- servicios y llamadas APM;
- trazabilidad distribuida;
- experiencia web mediante EUM;
- pruebas Synthetic;
- eventos y Smart Alerts;
- dependencias entre servicios.

## Condición de falla

El escenario no apaga la aplicación. Durante la falla:

- CENTRAL continúa disponible;
- RETAIL continúa disponible;
- `/health` responde HTTP 200;
- la información crítica queda `STALE`;
- la transacción de negocio responde HTTP 503;
- Browser Synthetic falla;
- EUM registra `Checkout Failed`;
- Smart Alerts se abren.

La recuperación restablece la distribución de la información crítica y permite observar el cierre del ciclo de incidente.

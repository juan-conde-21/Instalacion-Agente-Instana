# IBM Instana - Retail Critical Business Flow

Laboratorio de demostración para evidenciar cómo IBM Instana detecta impacto real sobre un proceso de negocio aun cuando la infraestructura y los health checks continúan disponibles.

## Escenario

Flujo funcional:

SOURCE -> CENTRAL -> RETAIL -> CUSTOMER

Durante una falla controlada, CENTRAL y RETAIL permanecen UP, pero la información crítica queda obsoleta. La operación de negocio responde HTTP 503 y la experiencia del usuario se degrada.

## Qué demuestra

- APM y trazabilidad distribuida.
- Website Monitoring y EUM.
- Synthetic HTTP y Browser Synthetic.
- Smart Alerts orientadas a impacto.
- Dependencias entre `retail-app` y `central-service`.
- Automatización de configuración y validación mediante API.

Flujo demostrado:

HEALTHY -> Synthetic PASS -> fault -> negocio 503 -> Browser Synthetic FAIL -> EUM Checkout Failed -> Smart Alerts OPEN -> recover -> Synthetic PASS -> Smart Alerts CLOSED -> Dependencies RETAIL -> CENTRAL

## Ejecutar la demo

```bash
cd /opt/instana-demo/demo
./demo.sh status
./run-demo.sh
```

Modo automático:

```bash
./run-demo.sh --auto
```

## Validación final

La última auditoría funcional del laboratorio confirmó:

- Checks OK: 12
- Advertencias: 0
- Estado: `READY FOR DEMO`
- Dependencia `RETAIL -> CENTRAL` detectada.

## Seguridad

El repositorio no debe contener credenciales ni artefactos runtime. Se excluyen `secrets/`, `state/`, `logs/`, archivos `.env`, claves privadas y tokens.

## Documentación

- [Arquitectura](docs/ARCHITECTURE.md)
- [Runbook de la demo](docs/DEMO-RUNBOOK.md)

## Portabilidad

Esta versión conserva algunos identificadores y parámetros propios del laboratorio validado. No son secretos. Para desplegar el escenario en otro tenant o infraestructura deben ajustarse endpoints, direcciones y objetos de Instana según el ambiente.

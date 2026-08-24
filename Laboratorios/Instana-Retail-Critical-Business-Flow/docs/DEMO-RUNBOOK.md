# Demo Runbook

## 1. Validar estado inicial

```bash
cd /opt/instana-demo/demo
./demo.sh status
```

Esperado: `FLUJO DE NEGOCIO : HEALTHY`.

## 2. Ejecutar la historia completa

```bash
./run-demo.sh
```

Para ejecución sin pausas:

```bash
./run-demo.sh --auto
```

## 3. Ejecución manual

```bash
./demo.sh fault
./demo.sh observe
./demo.sh recover
./demo.sh status
```

Durante el incidente debe observarse infraestructura disponible, archivo crítico `STALE`, operación de negocio HTTP 503, Browser Synthetic FAIL, evento EUM `Checkout Failed` y Smart Alerts OPEN.

Después de la recuperación, el Browser Synthetic vuelve a PASS y las alertas pasan a CLOSED tras su ventana de evaluación.

## 4. Auditoría final

```bash
cd /opt/instana-demo/instana-api
./10a-final-lab-audit.sh
```

Resultado validado:

- Checks OK: 12
- Advertencias: 0
- `LAB STATUS : READY FOR DEMO`
- `RETAIL -> CENTRAL` visible en Dependencies usando `All Calls`.

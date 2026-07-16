# Monitoreo con IBM Instana de Node.js 14, PM2 y PostgreSQL en Ubuntu

Guía reproducible para desplegar y monitorear aplicaciones Node.js 14 administradas por PM2, con PostgreSQL instalado directamente sobre Ubuntu e instrumentación APM mediante IBM Instana.

## 1. Alcance

Este procedimiento cubre:

- Instalación aislada de Node.js `14.15.4`.
- Instalación de PM2 `5.3.1` usando Node.js 14.
- Ejecución de tres servicios Node.js en modo `cluster`.
- Instalación y configuración de PostgreSQL.
- Configuración de arranque automático de PM2 con `systemd`.
- Instalación del agente de Instana en Ubuntu.
- Creación de un usuario exclusivo para monitorear PostgreSQL.
- Activación de estadísticas requeridas por el sensor PostgreSQL.
- Instalación de `@instana/collector@3.21.1` en cada aplicación.
- Inicialización correcta del collector antes de cualquier otra dependencia.
- Generación de tráfico y validación de trazas distribuidas.
- Cambio del nivel de logging de Instana de `debug` a `info`.

> [!WARNING]
> Node.js 14 está fuera de soporte oficial y no recibe correcciones de seguridad. Esta guía está orientada a laboratorios, pruebas controladas o reproducción de plataformas heredadas. Para producción se recomienda migrar a una versión LTS vigente.

---

## 2. Arquitectura validada

```text
Ubuntu Server
│
├── Instana Host Agent
│   └── Receptor local: 127.0.0.1:42699
│
├── PostgreSQL 14
│   ├── Base: labdb
│   ├── Usuario aplicativo: labuser
│   └── Usuario de monitoreo: instana_monitor
│
└── PM2 5.3.1
    ├── lab-customers
    │   ├── instancia 1
    │   └── instancia 2
    │
    ├── lab-orders
    │   ├── instancia 1
    │   └── instancia 2
    │
    └── lab-notifications
        ├── instancia 1
        └── instancia 2
```

Flujo funcional:

```text
Cliente
  |
  v
orders-service :3002
  |
  +--> customers-service :3001
  |      └--> PostgreSQL
  |
  +--> PostgreSQL
  |
  └--> notifications-service :3003
         └--> PostgreSQL
```

Trazabilidad esperada en Instana:

```text
POST /orders
├── GET /customers/:id
│   └── SELECT PostgreSQL
├── INSERT PostgreSQL
└── POST /notifications
    └── INSERT PostgreSQL
```

---

## 3. Versiones utilizadas

| Componente | Versión validada |
|---|---:|
| Ubuntu Server | 22.04 LTS |
| Node.js | 14.15.4 |
| npm | 6.14.10 |
| PM2 | 5.3.1 |
| PostgreSQL | 14.x |
| Instana Node.js Collector | 3.21.1 |
| Arquitectura | Linux x86_64 |

IBM documenta que Node.js 14 es compatible con versiones del collector entre `1.97.0` y `3.21.1`. Por ese motivo se fija expresamente la versión `3.21.1` y no se instala `latest`.

---

## 4. Prerrequisitos

### 4.1 Sistema operativo

- Ubuntu Server con arquitectura `x86_64`.
- Acceso `root` o privilegios `sudo`.
- DNS y salida HTTPS disponibles.
- Fecha y hora sincronizadas.
- Espacio disponible en `/opt`, `/var/lib/postgresql` y `/root/.pm2/logs`.

Validar:

```bash
uname -m
cat /etc/os-release
date -u
df -h
```

Resultado esperado para la arquitectura:

```text
x86_64
```

### 4.2 Puertos locales

| Puerto | Uso |
|---:|---|
| 3001 | `customers-service` |
| 3002 | `orders-service` |
| 3003 | `notifications-service` |
| 5432 | PostgreSQL |
| 42699 | Comunicación del collector Node.js con el agente Instana |

Validar que no estén ocupados antes del despliegue:

```bash
ss -lntp | grep -E ':3001|:3002|:3003|:5432|:42699' || true
```

### 4.3 Paquetes base

```bash
apt-get update

DEBIAN_FRONTEND=noninteractive apt-get install -y \
  ca-certificates \
  curl \
  wget \
  xz-utils \
  unzip \
  build-essential \
  python3 \
  make \
  g++ \
  postgresql \
  postgresql-contrib
```

Los compiladores y Python permiten instalar dependencias nativas de Node.js cuando sean requeridas.

### 4.4 Propiedad de los archivos

El mismo usuario que instala las dependencias debe tener permisos de escritura sobre las aplicaciones y `node_modules`.

En este laboratorio PM2 se ejecuta con `root`, por lo que se utiliza:

```bash
chown -R root:root /opt/node14-pm2-postgresql-lab
chmod -R u+rwX,go+rX /opt/node14-pm2-postgresql-lab
```

En un entorno productivo se recomienda crear un usuario Linux dedicado en lugar de ejecutar aplicaciones como `root`.

---

# Parte I. Instalación de Node.js y PM2

## 5. Instalar Node.js 14.15.4 de forma aislada

No se reemplaza el runtime Node.js utilizado por otros productos instalados en el servidor. Node.js 14 queda disponible en una ruta independiente:

```text
/opt/node-v14.15.4
```

### 5.1 Descargar e instalar

```bash
cd /tmp

wget https://nodejs.org/download/release/v14.15.4/node-v14.15.4-linux-x64.tar.xz

tar -xJf node-v14.15.4-linux-x64.tar.xz -C /opt

ln -sfn \
  /opt/node-v14.15.4-linux-x64 \
  /opt/node-v14.15.4
```

### 5.2 Validar el runtime

```bash
/opt/node-v14.15.4/bin/node --version
/opt/node-v14.15.4/bin/npm --version
```

Resultado esperado:

```text
v14.15.4
6.14.10
```

### 5.3 Crear comandos independientes

#### `node14`

```bash
ln -sfn /opt/node-v14.15.4/bin/node /usr/local/bin/node14
```

#### `npm14`

```bash
cat >/usr/local/bin/npm14 <<'EOF'
#!/bin/bash
export PATH=/opt/node-v14.15.4/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
exec /opt/node-v14.15.4/bin/npm "$@"
EOF

chmod +x /usr/local/bin/npm14
```

Validar:

```bash
node14 --version
npm14 --version
```

---

## 6. Instalar PM2 5.3.1 con Node.js 14

```bash
export PATH=/opt/node-v14.15.4/bin:$PATH

npm install -g pm2@5.3.1
```

Crear un wrapper para garantizar que PM2 siempre use Node.js 14:

```bash
cat >/usr/local/bin/pm2-node14 <<'EOF'
#!/bin/bash
export PATH=/opt/node-v14.15.4/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
exec /opt/node-v14.15.4/bin/pm2 "$@"
EOF

chmod +x /usr/local/bin/pm2-node14
hash -r
```

Validar:

```bash
pm2-node14 --version
pm2-node14 ping
pm2-node14 ls
```

Resultado esperado:

```text
5.3.1
{ msg: 'pong' }
```

Confirmar que el daemon PM2 utiliza Node.js 14:

```bash
PM2_PID=$(pgrep -f "PM2.*God Daemon" | head -1)

echo "$PM2_PID"
readlink -f "/proc/$PM2_PID/exe"
```

Resultado esperado:

```text
/opt/node-v14.15.4-linux-x64/bin/node
```

---

# Parte II. PostgreSQL y aplicaciones

## 7. Iniciar PostgreSQL

```bash
systemctl enable --now postgresql
pg_lsclusters
```

El clúster debe aparecer en estado `online`.

Ejemplo:

```text
Ver Cluster Port Status Owner    Data directory              Log file
14  main    5432 online postgres /var/lib/postgresql/14/main  ...
```

---

## 8. Crear la base y el usuario aplicativo

> [!IMPORTANT]
> No publiques contraseñas reales en GitHub. Sustituye los valores de ejemplo por secretos administrados fuera del repositorio.

```bash
sudo -u postgres psql <<'SQL'
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_roles
    WHERE rolname = 'labuser'
  ) THEN
    CREATE ROLE labuser LOGIN PASSWORD '<LABUSER_PASSWORD>';
  END IF;
END
$$;

SELECT 'CREATE DATABASE labdb OWNER labuser'
WHERE NOT EXISTS (
  SELECT 1
  FROM pg_database
  WHERE datname = 'labdb'
)\gexec
SQL
```

Aplicar el esquema de la aplicación:

```bash
sudo -u postgres psql -d labdb <<'SQL'
SET ROLE labuser;

CREATE SCHEMA IF NOT EXISTS customer_data;
CREATE SCHEMA IF NOT EXISTS order_data;
CREATE SCHEMA IF NOT EXISTS notification_data;

CREATE TABLE IF NOT EXISTS customer_data.customers (
  id BIGSERIAL PRIMARY KEY,
  name VARCHAR(120) NOT NULL,
  email VARCHAR(180) NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS order_data.orders (
  id BIGSERIAL PRIMARY KEY,
  customer_id BIGINT NOT NULL,
  product VARCHAR(160) NOT NULL,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  unit_price NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0),
  total NUMERIC(12,2) NOT NULL CHECK (total >= 0),
  status VARCHAR(40) NOT NULL DEFAULT 'CREATED',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_orders_customer_id
  ON order_data.orders(customer_id);

CREATE TABLE IF NOT EXISTS notification_data.notifications (
  id BIGSERIAL PRIMARY KEY,
  event_type VARCHAR(80) NOT NULL,
  order_id BIGINT NOT NULL,
  customer_id BIGINT NOT NULL,
  recipient VARCHAR(180) NOT NULL,
  message TEXT NOT NULL,
  status VARCHAR(40) NOT NULL DEFAULT 'SENT',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_order_id
  ON notification_data.notifications(order_id);

INSERT INTO customer_data.customers (name, email)
VALUES
  ('Ana Torres', 'ana.torres@example.com'),
  ('Luis Paredes', 'luis.paredes@example.com')
ON CONFLICT (email) DO NOTHING;
SQL
```

---

## 9. Estructura de las aplicaciones

```text
/opt/node14-pm2-postgresql-lab/
├── ecosystem.config.js
├── database/
│   └── init.sql
└── services/
    ├── customers/
    │   ├── package.json
    │   ├── package-lock.json
    │   └── src/index.js
    ├── orders/
    │   ├── package.json
    │   ├── package-lock.json
    │   └── src/index.js
    └── notifications/
        ├── package.json
        ├── package-lock.json
        └── src/index.js
```

Instalar las dependencias de cada servicio:

```bash
for servicio in customers orders notifications
do
  echo "Instalando dependencias de $servicio"

  cd "/opt/node14-pm2-postgresql-lab/services/$servicio"

  npm14 ci --only=production
  node14 --check src/index.js
done
```

---

## 10. Configurar PM2

Archivo:

```text
/opt/node14-pm2-postgresql-lab/ecosystem.config.js
```

Configuración base, todavía sin Instana:

```javascript
'use strict';

const node14 = '/opt/node-v14.15.4/bin/node';
const baseDir = '/opt/node14-pm2-postgresql-lab';

const common = {
  namespace: 'node14-lab',
  script: 'src/index.js',
  interpreter: node14,
  exec_mode: 'cluster',
  instances: 2,
  autorestart: true,
  watch: false,
  restart_delay: 2000,
  max_memory_restart: '250M',
  kill_timeout: 10000,
  time: true,
  merge_logs: true
};

const database = {
  PGHOST: '127.0.0.1',
  PGPORT: '5432',
  PGDATABASE: 'labdb',
  PGUSER: 'labuser',
  PGPASSWORD: '<LABUSER_PASSWORD>'
};

module.exports = {
  apps: [
    {
      ...common,
      name: 'lab-customers',
      cwd: `${baseDir}/services/customers`,
      env: {
        NODE_ENV: 'production',
        SERVICE_NAME: 'customers-service',
        PORT: '3001',
        ...database
      }
    },
    {
      ...common,
      name: 'lab-notifications',
      cwd: `${baseDir}/services/notifications`,
      env: {
        NODE_ENV: 'production',
        SERVICE_NAME: 'notifications-service',
        PORT: '3003',
        ...database
      }
    },
    {
      ...common,
      name: 'lab-orders',
      cwd: `${baseDir}/services/orders`,
      env: {
        NODE_ENV: 'production',
        SERVICE_NAME: 'orders-service',
        PORT: '3002',
        CUSTOMERS_URL: 'http://127.0.0.1:3001',
        NOTIFICATIONS_URL: 'http://127.0.0.1:3003',
        HTTP_TIMEOUT_MS: '4000',
        ...database
      }
    }
  ]
};
```

Validar la sintaxis:

```bash
cd /opt/node14-pm2-postgresql-lab

node14 --check ecosystem.config.js
```

Iniciar:

```bash
pm2-node14 start ecosystem.config.js
pm2-node14 save
pm2-node14 ls
```

Deben aparecer seis procesos:

```text
lab-customers        2 instancias online
lab-orders           2 instancias online
lab-notifications    2 instancias online
```

---

## 11. Arranque automático de PM2

```bash
pm2-node14 startup systemd -u root --hp /root
pm2-node14 save
```

PM2 crea:

```text
/etc/systemd/system/pm2-root.service
```

Si el daemon se inició manualmente antes de crear la unidad, pasar su administración a `systemd`:

```bash
pm2-node14 save
pm2-node14 kill

systemctl daemon-reload
systemctl start pm2-root
systemctl enable pm2-root
```

Validar:

```bash
systemctl is-enabled pm2-root
systemctl is-active pm2-root
systemctl status pm2-root --no-pager
pm2-node14 ls
```

---

# Parte III. Agente Instana y PostgreSQL

## 12. Instalar el agente de Instana

Desde la interfaz de Instana:

```text
Agents & Collectors
→ Install agents
→ Linux
```

Seleccionar la modalidad requerida por el entorno y copiar el comando oficial generado por el tenant.

> [!IMPORTANT]
> El comando contiene la clave, el endpoint y la zona específicos del tenant. No publiques ese comando ni la clave del agente en GitHub.

Después de ejecutar el instalador:

```bash
systemctl is-enabled instana-agent
systemctl is-active instana-agent
systemctl status instana-agent --no-pager -l
```

Validar el receptor local:

```bash
ss -lntp | grep 42699
```

Resultado esperado:

```text
LISTEN ... 127.0.0.1:42699
```

---

## 13. Habilitar estadísticas de PostgreSQL

IBM Instana requiere:

```text
track_activities = on
track_counts     = on
track_io_timing  = on
```

Aplicar de forma persistente:

```bash
cd /tmp

sudo -u postgres psql -d postgres <<'SQL'
ALTER SYSTEM SET track_activities = 'on';
ALTER SYSTEM SET track_counts = 'on';
ALTER SYSTEM SET track_io_timing = 'on';

SELECT pg_reload_conf();
SQL
```

Validar:

```bash
sudo -u postgres psql -d postgres -P pager=off -c "
SELECT
  name,
  setting,
  source,
  sourcefile,
  pending_restart
FROM pg_settings
WHERE name IN (
  'track_activities',
  'track_counts',
  'track_io_timing'
)
ORDER BY name;
"
```

Resultado esperado:

```text
track_activities | on
track_counts     | on
track_io_timing  | on
```

Y:

```text
pending_restart = false
```

Validación directa:

```bash
sudo -u postgres psql -d postgres -c "SHOW track_activities;"
sudo -u postgres psql -d postgres -c "SHOW track_counts;"
sudo -u postgres psql -d postgres -c "SHOW track_io_timing;"
```

No editar manualmente:

```text
/var/lib/postgresql/14/main/postgresql.auto.conf
```

PostgreSQL administra este archivo mediante `ALTER SYSTEM`.

---

## 14. Crear el usuario de monitoreo

Ingresar a PostgreSQL:

```bash
cd /tmp
sudo -u postgres psql -d postgres
```

Crear el usuario y asignar permisos:

```sql
CREATE USER instana_monitor
WITH LOGIN
PASSWORD '<INSTANA_MONITOR_PASSWORD>';

GRANT SELECT ON pg_stat_database TO instana_monitor;

GRANT CONNECT ON DATABASE postgres TO instana_monitor;
GRANT CONNECT ON DATABASE labdb TO instana_monitor;

GRANT pg_monitor TO instana_monitor;
```

Salir:

```sql
\q
```

### Permisos otorgados

- `CONNECT` sobre las bases que serán monitoreadas.
- `SELECT` sobre `pg_stat_database`, permiso mínimo documentado por IBM.
- `pg_monitor`, rol predefinido de PostgreSQL orientado a herramientas de monitoreo.

El usuario no debe ser:

- `SUPERUSER`
- propietario de la base
- `CREATEDB`
- `CREATEROLE`
- usuario aplicativo

Validar:

```bash
sudo -u postgres psql -d postgres -P pager=off -c "
SELECT
  rolname,
  rolsuper,
  rolcreatedb,
  rolcreaterole,
  rolreplication,
  rolcanlogin
FROM pg_roles
WHERE rolname = 'instana_monitor';
"
```

Resultado esperado:

```text
rolsuper       = false
rolcreatedb    = false
rolcreaterole  = false
rolreplication = false
rolcanlogin    = true
```

Validar pertenencia a `pg_monitor`:

```bash
sudo -u postgres psql -d postgres -P pager=off -c "
SELECT pg_has_role(
  'instana_monitor',
  'pg_monitor',
  'member'
) AS has_pg_monitor;
"
```

Resultado esperado:

```text
t
```

---

## 15. Probar el usuario de monitoreo

```bash
cd /tmp

psql \
  -h 127.0.0.1 \
  -p 5432 \
  -U instana_monitor \
  -d labdb \
  -W \
  -P pager=off \
  -c "
SELECT
  current_user,
  current_database(),
  current_setting('track_activities') AS track_activities,
  current_setting('track_counts') AS track_counts,
  current_setting('track_io_timing') AS track_io_timing;
"
```

Resultado esperado:

```text
instana_monitor | labdb | on | on | on
```

Validar estadísticas:

```bash
psql \
  -h 127.0.0.1 \
  -p 5432 \
  -U instana_monitor \
  -d labdb \
  -W \
  -P pager=off \
  -c "
SELECT
  datname,
  numbackends,
  xact_commit,
  xact_rollback,
  blks_read,
  blks_hit,
  blk_read_time,
  blk_write_time
FROM pg_stat_database
ORDER BY datname;
"
```

---

## 16. Configurar el sensor PostgreSQL de Instana

Respaldar:

```bash
cp -a \
  /opt/instana/agent/etc/instana/configuration.yaml \
  "/opt/instana/agent/etc/instana/configuration.yaml.bak.$(date +%Y%m%d-%H%M%S)"
```

Editar:

```bash
vi /opt/instana/agent/etc/instana/configuration.yaml
```

Agregar una sola sección PostgreSQL:

```yaml
com.instana.plugin.postgresql:
  user: 'instana_monitor'
  password: '<INSTANA_MONITOR_PASSWORD>'
  database: 'labdb'
  poll_rate: 10
```

Consideraciones:

- `database` es la base utilizada para autenticar la conexión inicial.
- `poll_rate` está expresado en segundos.
- No usar `isRootlessPodman` para PostgreSQL instalado directamente sobre Ubuntu.
- El archivo contiene la contraseña en texto claro. Limitar sus permisos:

```bash
chown root:root /opt/instana/agent/etc/instana/configuration.yaml
chmod 600 /opt/instana/agent/etc/instana/configuration.yaml
```

El agente recarga normalmente este archivo de manera automática. Para una validación controlada:

```bash
systemctl restart instana-agent
sleep 30
systemctl status instana-agent --no-pager
```

Validar en la interfaz:

```text
Infrastructure
→ ubuntu-server
→ PostgreSQL
```

Métricas esperadas:

- conexiones
- commits y rollbacks
- tamaño de las bases
- cache hit ratio
- lecturas y escrituras
- tiempo de E/S
- versión y puerto
- límite de conexiones

---

# Parte IV. Collector Node.js

## 17. Compatibilidad del collector

Para Node.js `14.15.4` se utiliza:

```text
@instana/collector@3.21.1
```

No instalar:

```bash
npm install @instana/collector@latest
```

Fijar siempre la versión:

```bash
npm14 install --save-exact @instana/collector@3.21.1
```

---

## 18. Instalar el collector en cada aplicación

El collector debe instalarse localmente en cada proyecto porque cada servicio tiene su propio `package.json` y `node_modules`.

```bash
for servicio in customers orders notifications
do
  echo
  echo "Instalando Instana en $servicio"

  cd "/opt/node14-pm2-postgresql-lab/services/$servicio"

  npm14 install --save-exact @instana/collector@3.21.1
done
```

Validar:

```bash
for servicio in customers orders notifications
do
  echo
  echo "===== $servicio ====="

  cd "/opt/node14-pm2-postgresql-lab/services/$servicio"

  node14 -p \
    "require('./node_modules/@instana/collector/package.json').version"
done
```

Resultado esperado:

```text
3.21.1
3.21.1
3.21.1
```

El paquete debe quedar registrado en cada `package.json`:

```json
{
  "dependencies": {
    "@instana/collector": "3.21.1"
  }
}
```

---

## 19. Inicializar el collector en el código

Esta es la parte crítica de la instrumentación.

En aplicaciones CommonJS, la inicialización debe ejecutarse antes de cargar Express, HTTP, PostgreSQL, Axios o cualquier otra dependencia.

En cada archivo:

```text
services/customers/src/index.js
services/orders/src/index.js
services/notifications/src/index.js
```

El inicio debe quedar así:

```javascript
'use strict';

require('@instana/collector')();

const express = require('express');
const { Pool } = require('pg');
```

Para el servicio de órdenes, todos los demás módulos también deben quedar después:

```javascript
'use strict';

require('@instana/collector')();

const express = require('express');
const axios = require('axios');
const { Pool } = require('pg');
```

Reglas:

1. Deben existir los paréntesis finales:

   ```javascript
   require('@instana/collector')();
   ```

2. No es suficiente con:

   ```javascript
   require('@instana/collector');
   ```

3. No cargar otro paquete antes del collector.

4. Aplicar el cambio en cada aplicación, no solo en el servicio de entrada.

Validar:

```bash
for servicio in customers orders notifications
do
  echo
  echo "===== $servicio ====="

  head -n 10 \
    "/opt/node14-pm2-postgresql-lab/services/$servicio/src/index.js"

  node14 --check \
    "/opt/node14-pm2-postgresql-lab/services/$servicio/src/index.js"
done
```

---

## 20. Configurar variables de Instana en PM2

Agregar al `ecosystem.config.js`:

```javascript
const instanaCommon = {
  INSTANA_AGENT_HOST: '127.0.0.1',
  INSTANA_AGENT_PORT: '42699',

  // Usar debug solo durante la validación inicial.
  INSTANA_LOG_LEVEL: 'debug',

  // Captura stack trace únicamente para errores.
  INSTANA_STACK_TRACE: 'error'
};
```

No configurar simultáneamente `NODE_OPTIONS` si el collector ya se inicializa mediante:

```javascript
require('@instana/collector')();
```

### Configuración completa

```javascript
'use strict';

const node14 = '/opt/node-v14.15.4/bin/node';
const baseDir = '/opt/node14-pm2-postgresql-lab';

const common = {
  namespace: 'node14-lab',
  script: 'src/index.js',
  interpreter: node14,
  exec_mode: 'cluster',
  instances: 2,
  autorestart: true,
  watch: false,
  restart_delay: 2000,
  max_memory_restart: '250M',
  kill_timeout: 10000,
  time: true,
  merge_logs: true
};

const database = {
  PGHOST: '127.0.0.1',
  PGPORT: '5432',
  PGDATABASE: 'labdb',
  PGUSER: 'labuser',
  PGPASSWORD: '<LABUSER_PASSWORD>'
};

const instanaCommon = {
  INSTANA_AGENT_HOST: '127.0.0.1',
  INSTANA_AGENT_PORT: '42699',
  INSTANA_LOG_LEVEL: 'debug',
  INSTANA_STACK_TRACE: 'error'
};

module.exports = {
  apps: [
    {
      ...common,
      name: 'lab-customers',
      cwd: `${baseDir}/services/customers`,
      env: {
        NODE_ENV: 'production',
        SERVICE_NAME: 'customers-service',
        INSTANA_SERVICE_NAME: 'customers-service',
        INSTANA_PROCESS_NAME: 'lab-customers',
        PORT: '3001',
        ...instanaCommon,
        ...database
      }
    },
    {
      ...common,
      name: 'lab-notifications',
      cwd: `${baseDir}/services/notifications`,
      env: {
        NODE_ENV: 'production',
        SERVICE_NAME: 'notifications-service',
        INSTANA_SERVICE_NAME: 'notifications-service',
        INSTANA_PROCESS_NAME: 'lab-notifications',
        PORT: '3003',
        ...instanaCommon,
        ...database
      }
    },
    {
      ...common,
      name: 'lab-orders',
      cwd: `${baseDir}/services/orders`,
      env: {
        NODE_ENV: 'production',
        SERVICE_NAME: 'orders-service',
        INSTANA_SERVICE_NAME: 'orders-service',
        INSTANA_PROCESS_NAME: 'lab-orders',
        PORT: '3002',
        CUSTOMERS_URL: 'http://127.0.0.1:3001',
        NOTIFICATIONS_URL: 'http://127.0.0.1:3003',
        HTTP_TIMEOUT_MS: '4000',
        ...instanaCommon,
        ...database
      }
    }
  ]
};
```

### Nombres utilizados por Instana

| Variable | Función |
|---|---|
| `INSTANA_AGENT_HOST` | Dirección del host agent |
| `INSTANA_AGENT_PORT` | Puerto del host agent |
| `INSTANA_SERVICE_NAME` | Nombre del servicio en APM |
| `INSTANA_PROCESS_NAME` | Etiqueta de la entidad Node.js en infraestructura |
| `INSTANA_LOG_LEVEL` | Nivel de logs del collector |
| `INSTANA_STACK_TRACE` | Captura de stack traces |

Validar:

```bash
cd /opt/node14-pm2-postgresql-lab

node14 --check ecosystem.config.js
```

---

## 21. Validar conectividad con el agente

Usando el mismo Node.js que ejecuta las aplicaciones:

```bash
node14 - <<'NODE'
const net = require('net');

const socket = net.connect(42699, '127.0.0.1', () => {
  console.log('OK: Node.js puede conectarse al agente en 127.0.0.1:42699');
  socket.end();
});

socket.setTimeout(3000);

socket.on('timeout', () => {
  console.error('ERROR: timeout hacia 127.0.0.1:42699');
  socket.destroy();
  process.exit(1);
});

socket.on('error', error => {
  console.error(`ERROR: ${error.message}`);
  process.exit(1);
});
NODE
```

Resultado esperado:

```text
OK: Node.js puede conectarse al agente en 127.0.0.1:42699
```

---

## 22. Recrear los procesos PM2

Para garantizar que todos los procesos carguen el código y entorno actualizados:

```bash
pm2-node14 delete lab-customers
pm2-node14 delete lab-orders
pm2-node14 delete lab-notifications
```

Limpiar los logs de la prueba anterior:

```bash
pm2-node14 flush
```

Iniciar nuevamente:

```bash
cd /opt/node14-pm2-postgresql-lab

pm2-node14 start ecosystem.config.js
pm2-node14 save
pm2-node14 ls
```

Resultado esperado:

```text
lab-customers        cluster  online  2 instancias
lab-notifications    cluster  online  2 instancias
lab-orders           cluster  online  2 instancias
```

Confirmar la ruta y versión:

```bash
pm2-node14 describe lab-orders |
grep -E 'script path|exec cwd|node.js version|interpreter'
```

Resultado esperado:

```text
script path       /opt/node14-pm2-postgresql-lab/services/orders/src/index.js
interpreter       /opt/node-v14.15.4/bin/node
exec cwd          /opt/node14-pm2-postgresql-lab/services/orders
node.js version   14.15.4
```

---

## 23. Validar inicialización del collector

Durante la validación inicial, con `INSTANA_LOG_LEVEL=debug`:

```bash
grep -RiE \
'@instana/collector|announce|agentready|fully initialized|42699' \
/root/.pm2/logs/ |
tail -200
```

Mensajes esperados:

```text
@instana/collector module version: 3.21.1
Found an agent on 127.0.0.1:42699
Transitioning from unannounced to announced
The Instana host agent is ready to accept data
The Instana Node.js collector is now fully initialized and connected to the Instana host agent
```

Validar todos los procesos:

```bash
pm2-node14 ls

for app in lab-customers lab-orders lab-notifications
do
  echo "===== $app ====="

  grep -i \
    'fully initialized and connected to the Instana host agent' \
    "/root/.pm2/logs/${app}-out.log" |
    tail
done
```

---

## 24. Generar tráfico

Prueba corta:

```bash
for i in $(seq 1 20)
do
  curl -s -o /dev/null \
    -w "solicitud-$i HTTP %{http_code}\n" \
    -X POST http://localhost:3002/orders \
    -H 'Content-Type: application/json' \
    -H "x-correlation-id: instana-codigo-$i" \
    -d "{
      \"customerId\": 1,
      \"product\": \"Prueba collector $i\",
      \"quantity\": 1,
      \"unitPrice\": 100
    }"

  sleep 1
done
```

Resultado esperado:

```text
solicitud-1 HTTP 201
...
solicitud-20 HTTP 201
```

Prueba continua opcional:

```bash
while true
do
  ID=$(date +%s%N)

  curl -s -o /dev/null \
    -w "HTTP %{http_code}\n" \
    -X POST http://localhost:3002/orders \
    -H 'Content-Type: application/json' \
    -H "x-correlation-id: instana-$ID" \
    -d "{
      \"customerId\": 1,
      \"product\": \"Carga Instana\",
      \"quantity\": 1,
      \"unitPrice\": 100
    }"

  sleep 1
done
```

Detener con `Ctrl+C`.

---

## 25. Validar en la interfaz de Instana

### Infraestructura

```text
Infrastructure
→ ubuntu-server
```

Entidades esperadas:

```text
PostgreSQL 14
lab-customers
lab-orders
lab-notifications
```

### Aplicaciones y servicios

```text
Applications
→ Services
```

Servicios esperados:

```text
customers-service
orders-service
notifications-service
```

### Trazas

Buscar una llamada:

```text
POST /orders
```

Recorrido esperado:

```text
orders-service
├── customers-service
│   └── PostgreSQL
├── PostgreSQL
└── notifications-service
    └── PostgreSQL
```

---

# Parte V. Operación normal

## 26. Cambiar logs de `debug` a `info`

El nivel `debug` debe utilizarse solo durante la instalación o diagnóstico. Mantenerlo activo genera una cantidad considerable de logs y puede aumentar el consumo de disco.

Editar:

```bash
vi /opt/node14-pm2-postgresql-lab/ecosystem.config.js
```

Cambiar:

```javascript
INSTANA_LOG_LEVEL: 'debug',
```

por:

```javascript
INSTANA_LOG_LEVEL: 'info',
```

La configuración final debe quedar así:

```javascript
const instanaCommon = {
  INSTANA_AGENT_HOST: '127.0.0.1',
  INSTANA_AGENT_PORT: '42699',
  INSTANA_LOG_LEVEL: 'info',
  INSTANA_STACK_TRACE: 'error'
};
```

Verificar que no exista `INSTANA_DEBUG`:

```bash
grep -Rns \
  'INSTANA_DEBUG\|INSTANA_LOG_LEVEL' \
  /opt/node14-pm2-postgresql-lab/ecosystem.config.js
```

Validar sintaxis:

```bash
cd /opt/node14-pm2-postgresql-lab

node14 --check ecosystem.config.js
```

Aplicar el cambio:

```bash
pm2-node14 reload ecosystem.config.js --update-env
pm2-node14 save
```

Validar una instancia:

```bash
pm2-node14 ls
pm2-node14 env 0 | grep INSTANA_LOG_LEVEL
```

Resultado esperado:

```text
INSTANA_LOG_LEVEL=info
```

Después de confirmar que todos los procesos están `online`, limpiar los logs generados durante el diagnóstico:

```bash
pm2-node14 flush
```

Validar:

```bash
pm2-node14 logs --lines 50 --nostream
```

> [!NOTE]
> El nivel predeterminado del collector es `info`. También puede omitirse `INSTANA_LOG_LEVEL`, pero dejarlo explícito facilita la operación y auditoría.

---

## 27. Comandos operativos

### Estado

```bash
pm2-node14 ls
systemctl status pm2-root --no-pager
systemctl status instana-agent --no-pager
systemctl status postgresql --no-pager
```

### Logs

```bash
pm2-node14 logs
pm2-node14 logs lab-orders --lines 100
pm2-node14 logs --lines 100 --nostream
```

Los archivos se encuentran en:

```text
/root/.pm2/logs/
```

### Recarga

```bash
cd /opt/node14-pm2-postgresql-lab

pm2-node14 reload ecosystem.config.js --update-env
pm2-node14 save
```

### Reinicio de una aplicación

```bash
pm2-node14 restart lab-orders
```

### Monitor interactivo

```bash
pm2-node14 monit
```

---

## 28. Validación después de reiniciar Ubuntu

```bash
reboot
```

Después de volver a ingresar:

```bash
systemctl is-active postgresql
systemctl is-active instana-agent
systemctl is-active pm2-root

pm2-node14 ls
```

Validar los endpoints:

```bash
curl -s http://localhost:3001/health; echo
curl -s http://localhost:3002/health; echo
curl -s http://localhost:3003/health; echo
```

Validar una llamada distribuida:

```bash
curl -s \
  -X POST http://localhost:3002/orders \
  -H 'Content-Type: application/json' \
  -H 'x-correlation-id: prueba-post-reinicio' \
  -d '{
    "customerId": 1,
    "product": "Validación posterior al reinicio",
    "quantity": 1,
    "unitPrice": 100
  }'
```

---

## 29. Lista de comprobación

### Ubuntu y runtimes

- [ ] Ubuntu y arquitectura validados.
- [ ] Node.js `14.15.4` instalado en `/opt/node-v14.15.4`.
- [ ] `node14`, `npm14` y `pm2-node14` disponibles.
- [ ] PM2 ejecutándose con Node.js `14.15.4`.

### Aplicaciones

- [ ] Tres servicios desplegados.
- [ ] Dos instancias PM2 por servicio.
- [ ] Las seis instancias están `online`.
- [ ] PM2 persiste mediante `systemd`.

### PostgreSQL

- [ ] PostgreSQL está `online`.
- [ ] `track_activities=on`.
- [ ] `track_counts=on`.
- [ ] `track_io_timing=on`.
- [ ] Usuario `instana_monitor` creado.
- [ ] Usuario con `CONNECT` sobre las bases monitoreadas.
- [ ] Sensor PostgreSQL configurado en `configuration.yaml`.

### Node.js e Instana

- [ ] `@instana/collector@3.21.1` instalado en cada aplicación.
- [ ] `require('@instana/collector')();` es la primera inicialización.
- [ ] El collector puede comunicarse con `127.0.0.1:42699`.
- [ ] Los procesos anuncian inicialización completa.
- [ ] Los tres servicios aparecen en Instana.
- [ ] Las llamadas HTTP y PostgreSQL aparecen dentro de las trazas.
- [ ] El nivel de logs se cambió de `debug` a `info`.

---

## 30. Seguridad y mantenimiento

1. No publicar claves del agente Instana.
2. No publicar contraseñas de PostgreSQL.
3. Usar archivos de entorno o un gestor de secretos en producción.
4. Limitar los permisos del archivo de configuración del agente.
5. Mantener `INSTANA_LOG_LEVEL=info` durante la operación normal.
6. Monitorear el crecimiento de `/root/.pm2/logs`.
7. Planificar la migración desde Node.js 14 a una versión LTS vigente.
8. Validar la compatibilidad del collector antes de actualizar Node.js o `@instana/collector`.
9. Ejecutar `npm install` en la arquitectura y sistema operativo donde se ejecutará la aplicación.
10. Probar cualquier cambio de versiones en un ambiente no productivo.

---

## 31. Referencias oficiales

- [IBM Instana — Support information for the Node.js collector](https://www.ibm.com/docs/en/instana-observability?topic=nodejs-support-information)
- [IBM Instana — Setting up agent-based Node.js monitoring](https://www.ibm.com/docs/en/instana-observability?topic=nodejs-collector-installation)
- [IBM Instana — Configuring the Node.js collector](https://www.ibm.com/docs/en/instana-observability?topic=nodejs-collector-configuration)
- [IBM Instana — Node.js troubleshooting](https://www.ibm.com/docs/en/instana-observability?topic=nodejs-troubleshooting)
- [IBM Instana — Monitoring PostgreSQL](https://www.ibm.com/docs/en/instana-observability?topic=technologies-monitoring-postgresql)
- [Node.js — Release archive v14.15.4](https://nodejs.org/download/release/v14.15.4/)
- [Node.js — End-of-Life releases](https://nodejs.org/en/about/eol)
- [PM2 — Ecosystem file](https://pm2.keymetrics.io/docs/usage/application-declaration/)
- [PM2 — Cluster mode](https://pm2.keymetrics.io/docs/usage/cluster-mode/)
- [PM2 — Startup scripts](https://pm2.keymetrics.io/docs/usage/startup/)
- [PM2 — Log management](https://pm2.keymetrics.io/docs/usage/log-management/)
- [PostgreSQL 14 — Predefined roles](https://www.postgresql.org/docs/14/predefined-roles.html)

---

## 32. Resultado validado

La implementación fue validada con:

- seis procesos Node.js en modo `cluster`;
- Node.js `14.15.4` como intérprete de todos los procesos;
- collector `3.21.1` instalado en los tres servicios;
- comunicación exitosa con el host agent en `127.0.0.1:42699`;
- inicialización completa del collector;
- servicios y dependencias visibles en Instana;
- llamadas HTTP distribuidas entre los tres servicios;
- consultas y escrituras PostgreSQL asociadas a las trazas;
- generación sostenida de solicitudes con respuesta HTTP `201`;
- nivel de logging retornado a `info` al finalizar la validación.

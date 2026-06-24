# Demo IBM Instana: Apache HTTPD + Spring Boot + MySQL

Guía de laboratorio para demostrar monitoreo y trazabilidad con **IBM Instana** usando **Apache HTTPD** como reverse proxy, una aplicación **Java Spring Boot** y una base de datos **MySQL**.

```text
Cliente / Script Bash
        ↓
Apache HTTPD :80
        ↓ reverse proxy
Spring Boot / Java :8080
        ↓ JDBC
MySQL :3306
```

## 1. Objetivo

Implementar una demo reproducible que permita evidenciar en Instana:

- Monitoreo del host Linux.
- Monitoreo de Apache HTTPD.
- Métricas de Apache mediante `server-status` y `ExtendedStatus`.
- Tracing de Apache HTTPD habilitado desde el agente Instana.
- Detección de JVM y aplicación Spring Boot.
- Trazas Java de endpoints REST.
- Llamadas JDBC hacia MySQL.
- Métricas del motor MySQL.
- Errores HTTP 500 controlados.
- Latencia artificial para pruebas de performance.
- Generación de tráfico con script Bash.

## 2. Ambiente validado

| Componente | Validado |
|---|---|
| Sistema operativo | Red Hat Enterprise Linux 9.8 |
| Apache HTTPD | Apache HTTPD 2.4.x |
| Java | OpenJDK 17 |
| Spring Boot | 3.3.6 |
| MySQL | MySQL 8.x |
| Publicación | Apache HTTPD como reverse proxy |
| Ruta publicada | `http://<IP_SERVIDOR>/demo/api/...` |

> La guía fue validada en RHEL 9.8. Puede adaptarse a RHEL 8, RHEL 9 o superior, y Ubuntu. En Ubuntu cambian principalmente el nombre del servicio Apache, las rutas de configuración y los comandos de firewall.

## 3. Consideraciones por sistema operativo

### RHEL 8 / RHEL 9 / RHEL 9.8

```text
Servicio Apache : httpd
Config Apache   : /etc/httpd/conf.d/
Logs Apache     : /var/log/httpd/
Comando test    : apachectl configtest
Reinicio        : systemctl restart httpd
```

### Ubuntu 22.04 / 24.04 o superior

```text
Servicio Apache : apache2
Config Apache   : /etc/apache2/sites-available/ y /etc/apache2/conf-available/
Logs Apache     : /var/log/apache2/
Comando test    : apache2ctl configtest
Reinicio        : systemctl restart apache2
```

En esta guía se usa RHEL como flujo principal y se agregan notas equivalentes para Ubuntu cuando aplica.

## 4. Requisitos

### Infraestructura recomendada para demo

| Recurso | Recomendado |
|---|---:|
| CPU | 2 a 4 vCPU |
| RAM | 4 a 8 GB |
| Disco | 20 GB o más |
| Red | Salida a internet para paquetes y dependencias |

### Software requerido

- Usuario `root` o usuario con `sudo`.
- Apache HTTPD.
- Java 17.
- Maven.
- MySQL 8.x.
- `curl`.
- Instana Host Agent instalado en el servidor.

## 5. Instalación de paquetes base

### RHEL

```bash
dnf update -y

dnf install -y \
  httpd \
  java-17-openjdk \
  java-17-openjdk-devel \
  maven \
  git \
  curl \
  wget \
  unzip \
  policycoreutils-python-utils
```

Validar:

```bash
java -version
mvn -version
httpd -v
```

Evidencia esperada:

```text
openjdk version "17..."
Apache/2.4...
Apache Maven ...
```

### Ubuntu

```bash
sudo apt update
sudo apt install -y \
  apache2 \
  openjdk-17-jdk \
  maven \
  git \
  curl \
  wget \
  unzip \
  mysql-server

sudo a2enmod proxy proxy_http headers status
sudo systemctl restart apache2
```

## 6. Instalación de MySQL

### RHEL 9.6 o superior

Si el stream `mysql:8.4` está disponible:

```bash
dnf module list mysql
dnf module install -y mysql:8.4/server
systemctl enable --now mysqld.service
```

### RHEL 8 / RHEL 9 con MySQL 8.0

```bash
dnf module install -y mysql:8.0/server
systemctl enable --now mysqld.service
```

O, según repositorios habilitados:

```bash
dnf install -y mysql-server
systemctl enable --now mysqld.service
```

### Ubuntu

```bash
sudo apt install -y mysql-server
sudo systemctl enable --now mysql
```

## 7. Ejecución de `mysql_secure_installation`

Ejecutar:

```bash
mysql_secure_installation
```

Para esta demo se usó la contraseña:

```text
password
```

> Importante: `password` es solo para laboratorio. No usar esta clave en ambientes productivos ni subir secretos reales al repositorio.

### Mensajes típicos y respuestas sugeridas para la demo

#### 1. Password actual de root

```text
Enter password for user root:
```

Si ya existe clave, ingresar:

```text
password
```

Si es instalación nueva y no existe clave previa, presionar `Enter`.

#### 2. Validar política de password

```text
Would you like to setup VALIDATE PASSWORD component?
Press y|Y for Yes, any other key for No:
```

Para simplificar la demo:

```text
n
```

> Si respondes `y`, MySQL puede exigir una contraseña más compleja y rechazar `password`.

#### 3. Cambiar password de root

```text
Change the password for root ? ((Press y|Y for Yes, any other key for No) :
```

Responder:

```text
y
```

Luego ingresar:

```text
New password: password
Re-enter new password: password
```

#### 4. Remover usuarios anónimos

```text
Remove anonymous users? (Press y|Y for Yes, any other key for No) :
```

Responder:

```text
y
```

#### 5. Deshabilitar login remoto de root

```text
Disallow root login remotely? (Press y|Y for Yes, any other key for No) :
```

Responder:

```text
y
```

#### 6. Remover base de datos de prueba

```text
Remove test database and access to it? (Press y|Y for Yes, any other key for No) :
```

Responder:

```text
y
```

#### 7. Recargar privilegios

```text
Reload privilege tables now? (Press y|Y for Yes, any other key for No) :
```

Responder:

```text
y
```

Validar MySQL:

```bash
systemctl status mysqld --no-pager
mysql -u root -p -e "SELECT VERSION();"
```

Password:

```text
password
```

## 8. Crear base de datos y usuario de aplicación

Ingresar:

```bash
mysql -u root -p
```

Password:

```text
password
```

Ejecutar:

```sql
CREATE DATABASE instana_demo_db;

CREATE USER 'instana_user'@'localhost' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON instana_demo_db.* TO 'instana_user'@'localhost';
FLUSH PRIVILEGES;

USE instana_demo_db;

CREATE TABLE products (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE orders_demo (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    quantity INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO products (name, price) VALUES
('Laptop Demo', 3500.00),
('Monitor Demo', 950.00),
('Keyboard Demo', 120.00),
('Mouse Demo', 80.00);

SELECT * FROM products;
EXIT;
```

Validar con el usuario de la aplicación:

```bash
mysql -u instana_user -p instana_demo_db -e "SELECT * FROM products;"
```

Password:

```text
password
```

Evidencia esperada:

```text
+----+---------------+---------+---------------------+
| id | name          | price   | created_at          |
+----+---------------+---------+---------------------+
|  1 | Laptop Demo   | 3500.00 | ...                 |
|  2 | Monitor Demo  |  950.00 | ...                 |
|  3 | Keyboard Demo |  120.00 | ...                 |
|  4 | Mouse Demo    |   80.00 | ...                 |
+----+---------------+---------+---------------------+
```

## 9. Crear usuario MySQL de monitoreo para Instana

Para métricas más completas de MySQL, crear un usuario de monitoreo. Instana requiere credenciales para monitoreo profundo y permisos de lectura sobre `performance_schema`.

Ingresar:

```bash
mysql -u root -p
```

Ejecutar:

```sql
CREATE USER 'instana_mon'@'localhost' IDENTIFIED BY 'password';

GRANT REPLICATION CLIENT ON *.* TO 'instana_mon'@'localhost';
GRANT PROCESS ON *.* TO 'instana_mon'@'localhost';

GRANT SELECT ON performance_schema.events_waits_summary_global_by_event_name TO 'instana_mon'@'localhost';
GRANT SELECT ON performance_schema.events_statements_summary_by_digest TO 'instana_mon'@'localhost';
GRANT SELECT ON performance_schema.events_statements_summary_global_by_event_name TO 'instana_mon'@'localhost';
GRANT SELECT ON performance_schema.replication_connection_status TO 'instana_mon'@'localhost';

FLUSH PRIVILEGES;
EXIT;
```

> Si alguna tabla de `performance_schema` no existe en tu versión, ajustar el permiso según corresponda. Para la trazabilidad JDBC de la demo, el usuario de aplicación es suficiente; el usuario `instana_mon` ayuda a mostrar métricas del motor MySQL.

## 10. Crear aplicación Spring Boot

Crear estructura:

```bash
mkdir -p /opt/instana-demo-app
cd /opt/instana-demo-app
mkdir -p src/main/java/com/demo/instana
mkdir -p src/main/resources
```

### 10.1. `pom.xml`

```bash
cat > pom.xml <<'EOF'
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">

    <modelVersion>4.0.0</modelVersion>

    <groupId>com.demo</groupId>
    <artifactId>instana-apache-mysql-demo</artifactId>
    <version>1.0.0</version>
    <name>instana-apache-mysql-demo</name>
    <description>Demo Spring Boot + MySQL + Apache para trazabilidad Instana</description>

    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.3.6</version>
        <relativePath/>
    </parent>

    <properties>
        <java.version>17</java.version>
    </properties>

    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>

        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-jdbc</artifactId>
        </dependency>

        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-actuator</artifactId>
        </dependency>

        <dependency>
            <groupId>com.mysql</groupId>
            <artifactId>mysql-connector-j</artifactId>
            <scope>runtime</scope>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>
</project>
EOF
```

### 10.2. `application.properties`

```bash
cat > src/main/resources/application.properties <<'EOF'
server.port=8080
spring.application.name=instana-apache-mysql-demo

spring.datasource.url=jdbc:mysql://localhost:3306/instana_demo_db?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC
spring.datasource.username=instana_user
spring.datasource.password=password
spring.datasource.driver-class-name=com.mysql.cj.jdbc.Driver

# Recomendado para que Instana obtenga métricas internas de Spring Boot por JMX/MBeans.
spring.jmx.enabled=true
management.endpoints.jmx.exposure.include=env,health,info,metrics

# Exposición HTTP limitada para validación operativa.
management.endpoints.web.exposure.include=health,info,metrics
management.endpoint.health.show-details=always

logging.level.root=INFO
logging.level.com.demo.instana=INFO
EOF
```

### 10.3. Clase principal

```bash
cat > src/main/java/com/demo/instana/InstanaDemoApplication.java <<'EOF'
package com.demo.instana;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class InstanaDemoApplication {
    public static void main(String[] args) {
        SpringApplication.run(InstanaDemoApplication.class, args);
    }
}
EOF
```

### 10.4. Controlador REST

```bash
cat > src/main/java/com/demo/instana/DemoController.java <<'EOF'
package com.demo.instana;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;
import org.springframework.http.ResponseEntity;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Random;

@RestController
@RequestMapping("/api")
public class DemoController {

    private final JdbcTemplate jdbcTemplate;
    private final Random random = new Random();

    public DemoController(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @GetMapping("/health-demo")
    public Map<String, Object> healthDemo() {
        return Map.of(
                "status", "OK",
                "service", "instana-apache-mysql-demo",
                "timestamp", LocalDateTime.now().toString()
        );
    }

    @GetMapping("/products")
    public List<Map<String, Object>> getProducts() {
        return jdbcTemplate.queryForList("SELECT id, name, price, created_at FROM products ORDER BY id");
    }

    @PostMapping("/orders")
    public Map<String, Object> createOrder() {
        List<Map<String, Object>> products = jdbcTemplate.queryForList("SELECT name FROM products ORDER BY RAND() LIMIT 1");
        String productName = products.isEmpty() ? "Default Product" : products.get(0).get("name").toString();
        int quantity = random.nextInt(5) + 1;

        jdbcTemplate.update("INSERT INTO orders_demo (product_name, quantity) VALUES (?, ?)", productName, quantity);

        return Map.of(
                "message", "Order created",
                "product", productName,
                "quantity", quantity,
                "timestamp", LocalDateTime.now().toString()
        );
    }

    @GetMapping("/orders")
    public List<Map<String, Object>> getOrders() {
        return jdbcTemplate.queryForList("SELECT id, product_name, quantity, created_at FROM orders_demo ORDER BY id DESC LIMIT 20");
    }

    @GetMapping("/slow")
    public Map<String, Object> slowEndpoint() throws InterruptedException {
        int delay = random.nextInt(3000) + 2000;
        Thread.sleep(delay);
        return Map.of("message", "Slow response generated", "delay_ms", delay, "timestamp", LocalDateTime.now().toString());
    }

    @GetMapping("/error")
    public ResponseEntity<Map<String, Object>> errorEndpoint() {
        return ResponseEntity.status(500).body(
                Map.of(
                        "error", "Controlled demo error",
                        "message", "This endpoint intentionally returns HTTP 500",
                        "timestamp", LocalDateTime.now().toString()
                )
        );
    }

    @GetMapping("/random")
    public ResponseEntity<?> randomEndpoint() throws InterruptedException {
        int option = random.nextInt(5);
        if (option == 0) return ResponseEntity.ok(healthDemo());
        if (option == 1) return ResponseEntity.ok(getProducts());
        if (option == 2) return ResponseEntity.ok(createOrder());
        if (option == 3) return ResponseEntity.ok(slowEndpoint());
        return errorEndpoint();
    }
}
EOF
```

## 11. Compilar y probar la aplicación

```bash
cd /opt/instana-demo-app
mvn clean package -DskipTests
ls -lh target/
```

Evidencia real observada:

```text
-rw------- 1 root root 25M Jun 23 21:58 instana-apache-mysql-demo-1.0.0.jar
-rw------- 1 root root 5.3K Jun 23 21:57 instana-apache-mysql-demo-1.0.0.jar.original
```

Ejecutar manualmente:

```bash
java -jar target/instana-apache-mysql-demo-1.0.0.jar
```

Probar en otra terminal:

```bash
curl http://localhost:8080/api/health-demo
curl http://localhost:8080/api/products
curl -X POST http://localhost:8080/api/orders
curl http://localhost:8080/api/orders
curl http://localhost:8080/api/slow
curl -i http://localhost:8080/api/error
curl http://localhost:8080/api/random
```

Evidencia esperada:

```text
{"status":"OK","service":"instana-apache-mysql-demo",...}
[{"id":1,"name":"Laptop Demo","price":3500.00,...}]
{"message":"Order created",...}
HTTP/1.1 500
{"message":"This endpoint intentionally returns HTTP 500","error":"Controlled demo error"}
```

Detener la ejecución manual con `CTRL + C`.

## 12. Publicar Spring Boot como servicio systemd

```bash
useradd --system --no-create-home --shell /sbin/nologin instanademo || true

cp /opt/instana-demo-app/target/instana-apache-mysql-demo-1.0.0.jar /opt/instana-demo-app/app.jar
chown -R instanademo:instanademo /opt/instana-demo-app
chmod 750 /opt/instana-demo-app
chmod 640 /opt/instana-demo-app/app.jar
```

Crear servicio:

```bash
cat > /etc/systemd/system/instana-demo-app.service <<'EOF'
[Unit]
Description=Instana Demo Spring Boot App
After=network.target mysqld.service
Wants=mysqld.service

[Service]
User=instanademo
Group=instanademo
WorkingDirectory=/opt/instana-demo-app
ExecStart=/usr/bin/java -jar /opt/instana-demo-app/app.jar --server.address=127.0.0.1
SuccessExitStatus=143
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
```

> Se usa `--server.address=127.0.0.1` para que Spring Boot no quede expuesto directamente. El acceso externo debe pasar por Apache HTTPD.

Habilitar y levantar:

```bash
systemctl daemon-reload
systemctl enable --now instana-demo-app
systemctl status instana-demo-app --no-pager
```

Evidencia real observada:

```text
● instana-demo-app.service - Instana Demo Spring Boot App
     Loaded: loaded (/etc/systemd/system/instana-demo-app.service; enabled; preset: disabled)
     Active: active (running) since Tue 2026-06-23 22:00:57 EDT
   Main PID: 2350423 (java)
     CGroup: /system.slice/instana-demo-app.service
             └─2350423 /usr/bin/java -jar /opt/instana-demo-app/app.jar --server.address=127.0.0.1
```

Validar logs:

```bash
journalctl -u instana-demo-app -f
```

Evidencia esperada:

```text
Tomcat initialized with port 8080 (http)
Tomcat started on port 8080 (http) with context path '/'
Started InstanaDemoApplication
HikariPool-1 - Start completed.
```

## 13. Configurar Apache HTTPD como reverse proxy

Validar módulos:

```bash
httpd -M | egrep 'proxy|proxy_http|headers'
```

Evidencia real observada:

```text
headers_module (shared)
proxy_module (shared)
proxy_http_module (shared)
```

Permitir conexión de Apache al backend local con SELinux:

```bash
setsebool -P httpd_can_network_connect 1
```

Crear VirtualHost:

```bash
cat > /etc/httpd/conf.d/instana-demo.conf <<'EOF'
<VirtualHost *:80>
    ServerName instana-demo.local

    ProxyPreserveHost On

    RequestHeader set X-Forwarded-Proto "http"
    RequestHeader set X-Forwarded-Port "80"

    ProxyPass        /demo/ http://127.0.0.1:8080/
    ProxyPassReverse /demo/ http://127.0.0.1:8080/

    ProxyPass        /demo http://127.0.0.1:8080/
    ProxyPassReverse /demo http://127.0.0.1:8080/

    ErrorLog logs/instana-demo-error.log
    CustomLog logs/instana-demo-access.log combined
</VirtualHost>
EOF
```

Validar y reiniciar:

```bash
apachectl configtest
systemctl enable --now httpd
systemctl restart httpd
systemctl status httpd --no-pager
```

Evidencia real observada:

```text
Syntax OK
● httpd.service - The Apache HTTP Server
     Active: active (running)
     Status: "Started, listening on: port 80"
```

### Ubuntu equivalente

```bash
sudo a2enmod proxy proxy_http headers status

sudo tee /etc/apache2/sites-available/instana-demo.conf > /dev/null <<'EOF'
<VirtualHost *:80>
    ServerName instana-demo.local
    ProxyPreserveHost On
    RequestHeader set X-Forwarded-Proto "http"
    RequestHeader set X-Forwarded-Port "80"
    ProxyPass        /demo/ http://127.0.0.1:8080/
    ProxyPassReverse /demo/ http://127.0.0.1:8080/
    ProxyPass        /demo http://127.0.0.1:8080/
    ProxyPassReverse /demo http://127.0.0.1:8080/
    ErrorLog ${APACHE_LOG_DIR}/instana-demo-error.log
    CustomLog ${APACHE_LOG_DIR}/instana-demo-access.log combined
</VirtualHost>
EOF

sudo a2ensite instana-demo.conf
sudo apache2ctl configtest
sudo systemctl restart apache2
```

## 14. Probar publicación por Apache

```bash
curl http://localhost/demo/api/health-demo
curl http://localhost/demo/api/products
curl -X POST http://localhost/demo/api/orders
curl http://localhost/demo/api/orders
curl http://localhost/demo/api/slow
curl -i http://localhost/demo/api/error
curl http://localhost/demo/api/random
```

Evidencia real observada:

```text
{"timestamp":"2026-06-23T22:02:15.891879741","status":"OK","service":"instana-apache-mysql-demo"}
[{"id":1,"name":"Laptop Demo","price":3500.00,...}]
{"timestamp":"2026-06-23T22:02:16.070340506","message":"Order created","product":"Monitor Demo","quantity":4}
{"delay_ms":3328,"timestamp":"2026-06-23T22:02:19.438870075","message":"Slow response generated"}
HTTP/1.1 500
Server: Apache/2.4.62 (Red Hat Enterprise Linux)
Server-Timing: intid;desc=445f0c8107ca1183
{"message":"This endpoint intentionally returns HTTP 500","error":"Controlled demo error"}
```

Validar puertos:

```bash
ss -lntp | egrep ':80|:8080|:3306'
```

Evidencia esperada:

```text
*:80                         users:(("httpd",...))
[::ffff:127.0.0.1]:8080       users:(("java",...))
*:3306                       users:(("mysqld",...))
```

## 15. Habilitar `server-status` y `ExtendedStatus` para Instana

Instana requiere `server-status` y `ExtendedStatus On` para mostrar métricas como tráfico, tráfico por request y CPU.

Validar `mod_status`:

```bash
httpd -M | grep status
```

Debe aparecer:

```text
status_module (shared)
```

Si no aparece en RHEL:

```bash
cat > /etc/httpd/conf.modules.d/99-status.conf <<'EOF'
LoadModule status_module modules/mod_status.so
EOF
```

Crear configuración:

```bash
cat > /etc/httpd/conf.d/zz-instana-server-status.conf <<'EOF'
ExtendedStatus On

<Location "/server-status">
    SetHandler server-status
    Require local
</Location>
EOF
```

Validar que no exista `ExtendedStatus Off`:

```bash
grep -Rni "ExtendedStatus" /etc/httpd/
```

Si aparece `ExtendedStatus Off`, comentarlo o cambiarlo a:

```text
ExtendedStatus On
```

Validar y reiniciar Apache:

```bash
apachectl configtest
systemctl restart httpd
```

> Punto importante de la demo: para este caso se recomienda **reiniciar Apache** con `systemctl restart httpd`, no solo hacer `reload`. En la validación práctica, el reinicio fue necesario para que Instana reconozca correctamente `server-status`, `ExtendedStatus` y el tracing HTTPD.

Validar endpoint local:

```bash
curl -s http://127.0.0.1/server-status?auto | egrep 'Total Accesses|Total kBytes|CPULoad|ReqPerSec|BytesPerSec|BytesPerReq|BusyWorkers|IdleWorkers'
```

Evidencia esperada:

```text
Total Accesses: ...
Total kBytes: ...
CPULoad: ...
ReqPerSec: ...
BytesPerSec: ...
BytesPerReq: ...
BusyWorkers: ...
IdleWorkers: ...
```

Validar que no esté expuesto por IP externa:

```bash
SERVER_IP=$(hostname -I | awk '{print $1}')
curl -I http://${SERVER_IP}/server-status
```

Resultado esperado:

```text
HTTP/1.1 403 Forbidden
```

### Ubuntu equivalente

```bash
sudo tee /etc/apache2/conf-available/instana-server-status.conf > /dev/null <<'EOF'
ExtendedStatus On

<Location "/server-status">
    SetHandler server-status
    Require local
</Location>
EOF

sudo a2enmod status
sudo a2enconf instana-server-status
sudo apache2ctl configtest
sudo systemctl restart apache2
```

## 16. Configuración del Instana Host Agent

Instalar el agente desde la UI de Instana:

```text
Instana UI → More → Agents → Install Agent → Linux
```

> No colocar `agent key`, `download key` ni endpoints privados en el repositorio. Usar placeholders o variables.

Validar servicio:

```bash
systemctl status instana-agent --no-pager
```

Ruta habitual del archivo de configuración:

```bash
/opt/instana/agent/etc/instana/configuration.yaml
```

Validar:

```bash
ls -lh /opt/instana/agent/etc/instana/configuration.yaml
```

## 17. Habilitar tracing de Apache HTTPD en Instana

Editar:

```bash
vi /opt/instana/agent/etc/instana/configuration.yaml
```

Agregar o descomentar:

```yaml
com.instana.plugin.httpd:
  tracing:
    enabled: true
```

> Evitar duplicar bloques `com.instana.plugin.httpd`. Si ya existe, editar el bloque existente. La indentación YAML debe ser de dos espacios.

Reiniciar Instana Agent:

```bash
systemctl restart instana-agent
systemctl status instana-agent --no-pager
```

Reiniciar Apache para cargar el módulo de tracing:

```bash
systemctl restart httpd
```

En Ubuntu:

```bash
sudo systemctl restart apache2
```

Validar:

```bash
curl -i http://localhost/demo/api/health-demo
```

Evidencia esperada:

```text
HTTP/1.1 200
Server: Apache/2.4...
Server-Timing: intid;desc=...
```

## 18. Configurar MySQL en Instana Agent

Editar:

```bash
vi /opt/instana/agent/etc/instana/configuration.yaml
```

Agregar o ajustar:

```yaml
com.instana.plugin.mysql:
  enabled: true
  user: 'instana_mon'
  password: 'password'
  poll_rate: 10
  schema_excludes: ['INFORMATION_SCHEMA', 'PERFORMANCE_SCHEMA']
```

> En producción, no dejar contraseñas planas ni subir secretos al repositorio.

Reiniciar agente:

```bash
systemctl restart instana-agent
systemctl status instana-agent --no-pager
```

Validar MySQL:

```bash
systemctl status mysqld --no-pager
ss -lntp | grep 3306
```

## 19. Validar monitoreo Java / Spring Boot

La aplicación ya incluye Actuator y JMX:

```properties
spring.jmx.enabled=true
management.endpoints.jmx.exposure.include=env,health,info,metrics
management.endpoints.web.exposure.include=health,info,metrics
```

Validar Actuator:

```bash
curl http://localhost:8080/actuator/health
curl http://localhost:8080/actuator/metrics | head
```

Validar por Apache:

```bash
curl http://localhost/demo/actuator/health
```

Si el agente Instana se instaló después de levantar la app, reiniciar la aplicación:

```bash
systemctl restart instana-demo-app
systemctl status instana-demo-app --no-pager
```

## 20. Crear script generador de tráfico

Crear:

```bash
cat > /opt/instana-demo-app/generate-traffic.sh <<'EOF'
#!/usr/bin/env bash

set -u

BASE_URL="${1:-http://localhost/demo/api}"
DURATION_SECONDS="${DURATION_SECONDS:-300}"
SLEEP_SECONDS="${SLEEP_SECONDS:-1}"

END_TIME=$((SECONDS + DURATION_SECONDS))

TOTAL=0
OK=0
ERRORS=0
SLOW=0
POSTS=0
DB_READS=0

echo "===================================================="
echo " Generador de tráfico - Instana Demo"
echo "===================================================="
echo " Base URL        : ${BASE_URL}"
echo " Duración        : ${DURATION_SECONDS} segundos"
echo " Pausa           : ${SLEEP_SECONDS} segundos"
echo " Inicio          : $(date)"
echo "===================================================="

request() {
    local method="$1"
    local path="$2"
    local label="$3"
    local response
    local http_code
    local time_total

    if [ "$method" = "POST" ]; then
        response=$(curl -s -o /dev/null -w "%{http_code} %{time_total}" -X POST "${BASE_URL}${path}")
    else
        response=$(curl -s -o /dev/null -w "%{http_code} %{time_total}" "${BASE_URL}${path}")
    fi

    http_code=$(echo "$response" | awk '{print $1}')
    time_total=$(echo "$response" | awk '{print $2}')

    TOTAL=$((TOTAL + 1))

    if [[ "$http_code" =~ ^2 ]]; then
        OK=$((OK + 1))
    else
        ERRORS=$((ERRORS + 1))
    fi

    case "$label" in
        slow) SLOW=$((SLOW + 1)) ;;
        post_order) POSTS=$((POSTS + 1)) ;;
        db_read) DB_READS=$((DB_READS + 1)) ;;
    esac

    printf "[%s] %-12s %-18s HTTP=%s TIME=%ss\n" \
        "$(date '+%H:%M:%S')" "$method" "$path" "$http_code" "$time_total"
}

while [ "$SECONDS" -lt "$END_TIME" ]; do
    PICK=$((RANDOM % 100))

    if [ "$PICK" -lt 25 ]; then
        request "GET" "/health-demo" "health"
    elif [ "$PICK" -lt 50 ]; then
        request "GET" "/products" "db_read"
    elif [ "$PICK" -lt 70 ]; then
        request "POST" "/orders" "post_order"
    elif [ "$PICK" -lt 80 ]; then
        request "GET" "/orders" "db_read"
    elif [ "$PICK" -lt 90 ]; then
        request "GET" "/slow" "slow"
    elif [ "$PICK" -lt 96 ]; then
        request "GET" "/random" "random"
    else
        request "GET" "/error" "error"
    fi

    if (( TOTAL % 20 == 0 )); then
        echo "---------------- Resumen parcial ----------------"
        echo "Total requests : $TOTAL"
        echo "OK             : $OK"
        echo "Errores        : $ERRORS"
        echo "DB reads       : $DB_READS"
        echo "POST orders    : $POSTS"
        echo "Slow requests  : $SLOW"
        echo "-------------------------------------------------"
    fi

    sleep "$SLEEP_SECONDS"
done

echo "===================================================="
echo " Fin de generación de tráfico"
echo "===================================================="
echo " Total requests : $TOTAL"
echo " OK             : $OK"
echo " Errores        : $ERRORS"
echo " DB reads       : $DB_READS"
echo " POST orders    : $POSTS"
echo " Slow requests  : $SLOW"
echo " Fin            : $(date)"
echo "===================================================="
EOF

chmod +x /opt/instana-demo-app/generate-traffic.sh
```

## 21. Ejecución principal de la demo

Ejecutar durante 5 minutos:

```bash
DURATION_SECONDS=300 SLEEP_SECONDS=1 /opt/instana-demo-app/generate-traffic.sh
```

Este comando usa por defecto:

```text
http://localhost/demo/api
```

Por lo tanto, el tráfico atraviesa:

```text
Script Bash → Apache HTTPD :80 → Spring Boot :8080 → MySQL :3306
```

### Qué genera el script

| Endpoint | Tipo | Objetivo en Instana |
|---|---|---|
| `/health-demo` | GET | Request simple |
| `/products` | GET | SELECT a MySQL |
| `/orders` | POST | INSERT a MySQL |
| `/orders` | GET | SELECT adicional a MySQL |
| `/slow` | GET | Latencia artificial |
| `/error` | GET | Error HTTP 500 controlado |
| `/random` | GET | Tráfico mixto |

### Ejecutar por IP del servidor

```bash
DURATION_SECONDS=300 SLEEP_SECONDS=1 /opt/instana-demo-app/generate-traffic.sh http://<IP_SERVIDOR>/demo/api
```

### Ejecutar tráfico más intenso

```bash
DURATION_SECONDS=600 SLEEP_SECONDS=0.3 /opt/instana-demo-app/generate-traffic.sh
```

## 22. Evidencias durante el tráfico

Logs Apache en RHEL:

```bash
tail -f /var/log/httpd/instana-demo-access.log
```

Logs Apache en Ubuntu:

```bash
tail -f /var/log/apache2/instana-demo-access.log
```

Logs Spring Boot:

```bash
journalctl -u instana-demo-app -f
```

Conteo de órdenes:

```bash
mysql -u instana_user -p instana_demo_db -e "SELECT COUNT(*) AS total_orders FROM orders_demo;"
```

Últimas órdenes:

```bash
mysql -u instana_user -p instana_demo_db -e "SELECT * FROM orders_demo ORDER BY id DESC LIMIT 10;"
```

Métricas Apache:

```bash
curl -s http://127.0.0.1/server-status?auto | egrep 'Total Accesses|ReqPerSec|BytesPerSec|BytesPerReq|BusyWorkers|IdleWorkers'
```

## 23. Qué validar en Instana

### Infraestructura

- Host Linux.
- CPU, memoria, disco.
- Proceso `httpd`.
- Proceso `java`.
- Proceso `mysqld`.

### Apache HTTPD

Validar que no aparezcan mensajes como:

```text
There is no valid server-status defined in the HTTPd config file
```

```text
ExtendedStatus flag should be enabled in Apache HTTPd configuration
```

Si aparecen, revisar:

```bash
apachectl configtest
systemctl restart httpd
curl -s http://127.0.0.1/server-status?auto | head -20
```

### Java / Spring Boot

Validar:

- Servicio `instana-apache-mysql-demo`.
- Endpoints `/api/health-demo`, `/api/products`, `/api/orders`, `/api/slow`, `/api/error`, `/api/random`.
- Tiempos de respuesta.
- Errores HTTP 500.
- Dependencia JDBC hacia MySQL.

### MySQL

Validar:

- Proceso MySQL detectado.
- Puerto 3306.
- Métricas de base de datos.
- Consultas generadas por la aplicación.
- Relación Spring Boot → MySQL.

## 24. Narrativa sugerida para la demo

```text
La solicitud ingresa por Apache HTTPD en el puerto 80.
Apache funciona como reverse proxy y deriva el request a Spring Boot en 127.0.0.1:8080.
La aplicación Java procesa la solicitud y, según el endpoint, consulta o inserta información en MySQL.
Instana permite observar el recorrido, los tiempos de respuesta, los errores HTTP 500, la latencia artificial y la dependencia de base de datos.
```

Puntos recomendados:

1. Vista del host.
2. Sensor HTTPD y métricas de tráfico.
3. Endpoint `/server-status?auto` activo.
4. Servicio Java detectado.
5. Trazas de `/api/products` con consulta MySQL.
6. Trazas de `/api/slow` con mayor latencia.
7. Errores de `/api/error` como HTTP 500.
8. MySQL como dependencia del servicio Java.

## 25. Troubleshooting

### Instana muestra `There is no valid server-status defined`

```bash
httpd -M | grep status
cat /etc/httpd/conf.d/zz-instana-server-status.conf
apachectl configtest
systemctl restart httpd
curl -s http://127.0.0.1/server-status?auto | head -20
```

### Instana muestra `ExtendedStatus flag should be enabled`

```bash
grep -Rni "ExtendedStatus" /etc/httpd/
apachectl configtest
systemctl restart httpd
```

Debe quedar:

```apache
ExtendedStatus On
```

### Apache no conecta con Spring Boot en RHEL

```bash
getenforce
setsebool -P httpd_can_network_connect 1
curl http://127.0.0.1:8080/api/health-demo
curl http://localhost/demo/api/health-demo
```

### Spring Boot no levanta

```bash
systemctl status instana-demo-app --no-pager
journalctl -u instana-demo-app -n 100 --no-pager
java -version
mysql -u instana_user -p instana_demo_db -e "SELECT 1;"
```

### MySQL no responde

```bash
systemctl status mysqld --no-pager
ss -lntp | grep 3306
mysql -u root -p -e "SELECT VERSION();"
```

### No aparecen trazas Java en Instana

```bash
systemctl restart instana-agent
systemctl restart instana-demo-app
DURATION_SECONDS=300 SLEEP_SECONDS=1 /opt/instana-demo-app/generate-traffic.sh
```

Validar que el tráfico pase por Apache:

```bash
curl -i http://localhost/demo/api/health-demo
```

### No aparece `Server-Timing: intid`

```bash
grep -Rni "com.instana.plugin.httpd" /opt/instana/agent/etc/instana/configuration.yaml
systemctl restart instana-agent
systemctl restart httpd
curl -i http://localhost/demo/api/health-demo
```

## 26. Limpieza de la demo

```bash
systemctl stop instana-demo-app
systemctl stop httpd

systemctl disable instana-demo-app
rm -f /etc/systemd/system/instana-demo-app.service
systemctl daemon-reload

rm -f /etc/httpd/conf.d/instana-demo.conf
rm -f /etc/httpd/conf.d/zz-instana-server-status.conf
systemctl restart httpd
```

Eliminar base y usuarios:

```bash
mysql -u root -p <<'EOF'
DROP DATABASE IF EXISTS instana_demo_db;
DROP USER IF EXISTS 'instana_user'@'localhost';
DROP USER IF EXISTS 'instana_mon'@'localhost';
FLUSH PRIVILEGES;
EOF
```

Eliminar archivos:

```bash
rm -rf /opt/instana-demo-app
userdel instanademo || true
```

## 27. Comandos críticos de operación

### Reiniciar app

```bash
systemctl restart instana-demo-app
systemctl status instana-demo-app --no-pager
```

### Reiniciar Apache

```bash
apachectl configtest
systemctl restart httpd
```

### Validar publicación

```bash
curl http://localhost/demo/api/health-demo
curl http://localhost/demo/api/products
curl -i http://localhost/demo/api/error
```

### Validar `server-status`

```bash
curl -s http://127.0.0.1/server-status?auto | head -20
```

### Ejecutar demo de tráfico

```bash
DURATION_SECONDS=300 SLEEP_SECONDS=1 /opt/instana-demo-app/generate-traffic.sh
```

### Ejecutar demo con mayor intensidad

```bash
DURATION_SECONDS=600 SLEEP_SECONDS=0.3 /opt/instana-demo-app/generate-traffic.sh
```

## 28. Referencias oficiales

- IBM Instana - Monitoring HTTPd: https://www.ibm.com/docs/en/instana-observability?topic=technologies-monitoring-httpd
- IBM Instana - Monitoring Java virtual machine: https://www.ibm.com/docs/en/instana-observability?topic=technologies-monitoring-java-virtual-machine
- IBM Instana - Monitoring Spring Boot: https://www.ibm.com/docs/en/instana-observability?topic=technologies-monitoring-spring-boot
- IBM Instana - Monitoring MySQL: https://www.ibm.com/docs/en/instana-observability?topic=technologies-monitoring-mysql
- IBM Instana - Agent configuration file: https://www.ibm.com/docs/en/instana-observability?topic=cha-configuring-host-agents-by-using-agent-configuration-file
- Apache HTTP Server - mod_proxy: https://httpd.apache.org/docs/current/mod/mod_proxy.html
- Red Hat Enterprise Linux 9 - Deploying web servers and reverse proxies: https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/deploying_web_servers_and_reverse_proxies/
- Ubuntu Server - Install and configure MySQL: https://ubuntu.com/server/docs/how-to/databases/install-mysql/

## 29. Nota final

Esta demo está orientada a validación técnica, preventa, laboratorio y explicación de capacidades de observabilidad. Para ambientes productivos se recomienda:

- No usar contraseñas simples.
- No versionar secretos.
- Usar HTTPS/TLS en Apache.
- Restringir exposición de MySQL.
- Revisar hardening de Apache.
- Revisar SELinux y firewall.
- Separar aplicación, base de datos y monitoreo cuando corresponda.
- Definir naming estándar de servicios, zonas y aplicaciones en Instana.

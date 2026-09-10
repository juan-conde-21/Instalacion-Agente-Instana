# OpenTelemetry Collector Agent en OpenShift y configuración de puertos OTLP en Instana Agent

## Objetivo

Documentar la validación realizada en OpenShift para reproducir un
escenario donde existe un **OpenTelemetry Collector desplegado como
Agent mediante DaemonSet**, utilizando `hostPort` a nivel de nodo, y
validar el comportamiento de Instana Agent cuando existen conflictos de
puertos.

Adicionalmente, se documenta la configuración soportada por el **Instana
Agent Operator** para cambiar los puertos OTLP del agente cuando otra
carga de trabajo del cluster ya utiliza los puertos estándar.

El objetivo es demostrar que Instana puede continuar operando utilizando
puertos alternativos para OpenTelemetry sin modificar manualmente el
DaemonSet generado por el Operator.

------------------------------------------------------------------------

# 1. Arquitectura inicial del escenario

El primer escenario representa un ambiente donde OpenTelemetry Collector
utiliza puertos directamente sobre los nodos.

    OpenShift Cluster

    Worker Node

    +--------------------------------+
    | OpenTelemetry Collector Agent  |
    |                                |
    | DaemonSet                      |
    |                                |
    | hostPort 4317                  |
    | hostPort 4318                  |
    +--------------------------------+

Los puertos quedan reservados en el nodo:

-   4317/TCP - OTLP gRPC
-   4318/TCP - OTLP HTTP

Cuando otro componente intenta utilizar estos mismos puertos, Kubernetes
no permite programarlo.

------------------------------------------------------------------------

# 2. Despliegue de OpenTelemetry Collector como Agent

## 2.1 Crear namespace

``` bash
oc new-project observability-test
```

------------------------------------------------------------------------

## 2.2 Agregar repositorio Helm

``` bash
helm repo add open-telemetry \
https://open-telemetry.github.io/opentelemetry-helm-charts

helm repo update
```

------------------------------------------------------------------------

## 2.3 Crear archivo de configuración Helm

Crear el archivo:

``` bash
vi otel-values.yaml
```

Copiar el siguiente contenido:

``` yaml
mode: daemonset

image:
  repository: otel/opentelemetry-collector-contrib

ports:

  otlp:
    enabled: true
    containerPort: 4317
    hostPort: 4317
    protocol: TCP

  otlp-http:
    enabled: true
    containerPort: 4318
    hostPort: 4318
    protocol: TCP

  jaeger-grpc:
    enabled: true
    containerPort: 14250
    hostPort: 14250
    protocol: TCP

  jaeger-thrift:
    enabled: true
    containerPort: 14268
    hostPort: 14268
    protocol: TCP

  zipkin:
    enabled: true
    containerPort: 9411
    hostPort: 9411
    protocol: TCP
```

------------------------------------------------------------------------

## 2.4 Instalar OpenTelemetry Collector

``` bash
helm install otel-agent \
open-telemetry/opentelemetry-collector \
-n observability-test \
-f otel-values.yaml
```

------------------------------------------------------------------------

# 3. Configuración SCC en OpenShift

OpenShift bloquea por defecto el uso de `hostPort`.

El error inicial esperado:

    Host ports are not allowed to be used

Validar el ServiceAccount creado:

``` bash
oc get sa -n observability-test
```

Asignar permiso para utilizar `hostPort`:

``` bash
oc adm policy add-scc-to-user hostnetwork \
-z otel-agent-opentelemetry-collector \
-n observability-test
```

Validar:

``` bash
oc adm policy who-can use scc hostnetwork
```

------------------------------------------------------------------------

# 4. Validación del OpenTelemetry Collector

Validar los pods:

``` bash
oc get pods -n observability-test -o wide
```

Resultado esperado:

    otel-agent-opentelemetry-collector-agent   Running

Validar que los puertos están asociados al nodo:

``` bash
oc describe pod <otel-pod> \
-n observability-test | grep -A15 Ports
```

Resultado esperado:

    Ports:
    4317/TCP (otlp)
    4318/TCP (otlp-http)

    Host Ports:
    4317/TCP
    4318/TCP

------------------------------------------------------------------------

# 5. Validación del conflicto de puertos

Crear archivo:

``` bash
vi test-port.yaml
```

Copiar el contenido:

``` yaml
apiVersion: v1
kind: Pod

metadata:
  name: test-port-conflict
  namespace: observability-test

spec:

  containers:

  - name: nginx
    image: nginx

    ports:
    - containerPort: 4317
      hostPort: 4317
```

Aplicar:

``` bash
oc apply -f test-port.yaml
```

Validar:

``` bash
oc describe pod test-port-conflict \
-n observability-test
```

Resultado esperado:

    Status:
    Pending

Evento:

    FailedScheduling

    node(s) didn't have free ports for the requested pod ports

Esto confirma que Kubernetes considera los puertos ocupados a nivel del
nodo.

------------------------------------------------------------------------

# 6. Configuración de Instana Agent utilizando puertos alternativos

## 6.1 Validar capacidades del Instana Operator

Antes de modificar el despliegue, validar los campos soportados por el
CRD:

``` bash
oc explain instanaagent.spec
```

Para OpenTelemetry:

``` bash
oc explain instanaagent.spec.opentelemetry
```

Configuración de puerto gRPC:

``` bash
oc explain instanaagent.spec.opentelemetry.grpc.port
```

El Operator soporta configuración personalizada:

``` yaml
spec:
  opentelemetry:
    grpc:
      port:
    http:
      port:
```

------------------------------------------------------------------------

# 7. Crear configuración Instana con puertos personalizados

Crear archivo:

``` bash
vi instana-agent.yaml
```

Copiar el contenido:

``` yaml
apiVersion: instana.io/v1
kind: InstanaAgent

metadata:
  name: instana-agent
  namespace: instana-agent

spec:

  agent:

    configuration_yaml: |
      endpointHost: ingress-coral-saas.instana.io
      endpointPort: '443'

    key: <INSTANA_AGENT_KEY>

  cluster:
    name: Demo-Otel-Port

  opentelemetry:

    grpc:
      enabled: true
      port: 14317

    http:
      enabled: true
      port: 14318

  zone:
    name: Demo-Otel-Port
```

Aplicar:

``` bash
oc apply -f instana-agent.yaml
```

------------------------------------------------------------------------

# 8. Validación del despliegue Instana

Validar pods:

``` bash
oc get pods -n instana-agent -o wide
```

Validar el DaemonSet generado:

``` bash
oc describe daemonset instana-agent \
-n instana-agent
```

Confirmar que los endpoints OTLP utilizan los nuevos puertos:

    14317/TCP
    14318/TCP

------------------------------------------------------------------------

# 9. Resultado esperado

Con esta configuración la arquitectura queda:

    OpenShift Node

    +--------------------------------+
    | OpenTelemetry Collector        |
    |                                |
    | hostPort 4317                  |
    | hostPort 4318                  |
    +--------------------------------+


    +--------------------------------+
    | Instana Agent                  |
    |                                |
    | OTLP gRPC 14317                |
    | OTLP HTTP 14318                |
    +--------------------------------+

Los componentes dejan de competir por los mismos puertos.

------------------------------------------------------------------------

# Conclusión

El uso de `hostPort` en OpenTelemetry Collector puede generar conflictos
cuando otro agente de observabilidad requiere los mismos puertos a nivel
del nodo.

Para estos casos, Instana Agent Operator permite configurar puertos OTLP
personalizados mediante el recurso `InstanaAgent`, evitando
modificaciones manuales sobre el DaemonSet generado.

La recomendación es mantener la administración del agente mediante
Operator y utilizar la configuración del CRD para adaptar los puertos
cuando existan restricciones del ambiente.

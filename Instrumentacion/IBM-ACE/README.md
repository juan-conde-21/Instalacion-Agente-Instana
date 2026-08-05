# Procedimiento de corrección y validación de Instana AutoTrace Webhook para IBM ACE

## 1. Objetivo

Corregir la configuración del Instana AutoTrace Webhook y validar la instrumentación automática del deployment de IBM App Connect Enterprise (ACE), sin eliminar ni recrear la aplicación.

La validación se realizará sobre:

| Componente | Valor |
|---|---|
| Namespace de ACE | `middleware` |
| Deployment ACE | `ace-gestionpronaca-ibm-ace-server-icp4i-prod` |
| Versión ACE | `11.0.0.9` |
| Cloud Pak for Integration | `2020.1.1` |
| Namespace del webhook | `instana-autotrace-webhook` |
| Release Helm | `instana-autotrace-webhook` |
| Versión del webhook | `1.320.12` |
| Imagen de instrumentación | `icr.io/instana/instrumentation:1.320.12` |

El deployment `acp-transaccion` no forma parte de esta validación, debido a que corresponde a otro runtime y no al servidor ACE.

---

## 2. Diagnóstico identificado

El webhook registró el siguiente mensaje al crear nuevos pods de ACE:

```text
Pod ... ignored: Pod ... looks like an instance of some higher-order resource
```

Este comportamiento se presenta cuando el webhook trabaja en modo de mutación de recursos superiores:

```yaml
autotrace:
  enableHigherLevelResourceMutation: true
```

En ese modo, el webhook espera modificar directamente recursos como `Deployment`, `ReplicaSet`, `StatefulSet` o `DaemonSet`, y puede ignorar los pods que dependen de ellos.

Para la versión `1.320.12`, se utilizará el comportamiento actual recomendado:

```yaml
autotrace:
  enableHigherLevelResourceMutation: false
```

Con este valor, el webhook modifica directamente los pods nuevos. Por ello, un `rollout restart` del deployment será suficiente y no será necesario eliminar ni recrear el deployment de ACE.

También se mantendrá:

```yaml
autotrace:
  opt_in: false
```

De esta forma, no se requiere agregar el label `instana-autotrace=true` a cada deployment. Los recursos pueden excluirse puntualmente mediante `instana-autotrace=false`.

---

## 3. Consideraciones antes de iniciar

1. El webhook deberá permanecer en `0` réplicas durante la corrección y las validaciones previas.
2. Mientras el webhook esté detenido, no se deben reiniciar aplicaciones que se quieran instrumentar.
3. Se mantendrá `failurePolicy=Ignore`. Si el webhook no responde, OpenShift permitirá crear el pod, pero este se iniciará sin instrumentación.
4. No se modificará `ACE_ENABLE_OPEN_TRACING=false`. Para ACE `11.0.0.9`, el webhook utiliza el Instana ACE Tracing User Exit.
5. No se agregarán labels `instana-autotrace=true` al deployment.
6. No se bajará la versión del webhook.
7. No se eliminará ni recreará el deployment de ACE.
8. La activación del webhook se realizará mediante Helm para que el número de réplicas quede registrado en el release y no se pierda en una actualización posterior.

---

## 4. Validar el estado actual

Confirmar que el webhook continúa detenido:

```bash
oc get deployment instana-autotrace-webhook \
  -n instana-autotrace-webhook
```

Resultado esperado:

```text
READY   UP-TO-DATE   AVAILABLE
0/0     0            0
```

Validar la versión instalada:

```bash
helm list -n instana-autotrace-webhook
```

```bash
oc get deployment instana-autotrace-webhook \
  -n instana-autotrace-webhook \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

Resultado esperado:

```text
containers.instana.io/instana/release/agent/instana-autotrace-webhook:1.320.12
```

> Mientras el deployment del webhook permanezca en cero, no ejecutar reinicios de ACE.

---

## 5. Generar respaldos

Crear el directorio de respaldo:

```bash
mkdir -p autotrace-backup
```

Respaldar los valores efectivos del release Helm:

```bash
helm get values instana-autotrace-webhook \
  -n instana-autotrace-webhook \
  --all > autotrace-backup/instana-autotrace-values.yaml
```

Respaldar el manifiesto renderizado por Helm:

```bash
helm get manifest instana-autotrace-webhook \
  -n instana-autotrace-webhook \
  > autotrace-backup/instana-autotrace-manifest.yaml
```

Respaldar la configuración del admission webhook:

```bash
oc get mutatingwebhookconfiguration instana-autotrace-webhook \
  -o yaml > autotrace-backup/instana-autotrace-mwc.yaml
```

Respaldar el deployment de ACE:

```bash
oc get deployment ace-gestionpronaca-ibm-ace-server-icp4i-prod \
  -n middleware \
  -o yaml > autotrace-backup/ace-gestionpronaca-deployment.yaml
```

Registrar el historial del release:

```bash
helm history instana-autotrace-webhook \
  -n instana-autotrace-webhook \
  > autotrace-backup/instana-autotrace-helm-history.txt
```

---

## 6. Corregir el release del AutoTrace Webhook

Actualizar el release existente, conservando los valores actuales y modificando únicamente los parámetros necesarios.

El webhook se mantendrá en cero réplicas durante esta operación:

```bash
helm upgrade instana-autotrace-webhook instana-autotrace-webhook \
  --namespace instana-autotrace-webhook \
  --repo https://agents.instana.io/helm \
  --version 1.320.12 \
  --reuse-values \
  --set global.version=1.320.12 \
  --set openshift.enabled=true \
  --set autotrace.ace.enabled=true \
  --set autotrace.opt_in=false \
  --set autotrace.enableHigherLevelResourceMutation=false \
  --set autotrace.failurePolicy=Ignore \
  --set webhook.deployment.replicas=0
```

### Qué corrige este comando

| Parámetro | Finalidad |
|---|---|
| `global.version=1.320.12` | Mantiene alineadas las imágenes del webhook y de instrumentación. |
| `openshift.enabled=true` | Aplica la configuración requerida para OpenShift. |
| `autotrace.ace.enabled=true` | Habilita la instrumentación automática para ACE. |
| `autotrace.opt_in=false` | No exige etiquetar cada deployment con `instana-autotrace=true`. |
| `autotrace.enableHigherLevelResourceMutation=false` | El webhook modifica los pods nuevos directamente. |
| `autotrace.failurePolicy=Ignore` | Evita bloquear la creación de pods si el webhook no responde. |
| `webhook.deployment.replicas=0` | Mantiene detenido el webhook durante la validación. |

No se modifican las configuraciones actuales de IBM MQ, Node.js, Python, .NET u otras tecnologías.

---

## 7. Validar la corrección antes de iniciar el webhook

### 7.1 Validar los valores efectivos de Helm

```bash
helm get values instana-autotrace-webhook \
  -n instana-autotrace-webhook \
  --all | grep -A4 -B3 -E \
  'version:|openshift:|opt_in:|enableHigherLevelResourceMutation|failurePolicy|ace:|replicas:'
```

Se debe confirmar:

```yaml
global:
  version: 1.320.12

openshift:
  enabled: true

autotrace:
  opt_in: false
  enableHigherLevelResourceMutation: false
  failurePolicy: Ignore
  ace:
    enabled: true

webhook:
  deployment:
    replicas: 0
```

### 7.2 Confirmar que no existan configuraciones duplicadas

```bash
oc get mutatingwebhookconfiguration -o name | grep -i instana
```

Se espera una sola configuración asociada con AutoTrace:

```text
mutatingwebhookconfiguration.admissionregistration.k8s.io/instana-autotrace-webhook
```

Si aparecen dos o más configuraciones de AutoTrace, no continuar con el reinicio de aplicaciones hasta identificar cuál corresponde al release activo.

### 7.3 Validar las reglas del admission webhook

```bash
oc get mutatingwebhookconfiguration instana-autotrace-webhook \
  -o jsonpath='{range .webhooks[*]}{"WEBHOOK="}{.name}{" FAILURE_POLICY="}{.failurePolicy}{"\n"}{range .rules[*]}{"  OPERATIONS="}{.operations}{" APIGROUPS="}{.apiGroups}{" RESOURCES="}{.resources}{"\n"}{end}{end}'
```

Con `enableHigherLevelResourceMutation=false`, deben existir reglas para pods y ConfigMaps.

No deberían aparecer como recursos de mutación:

```text
deployments
replicasets
statefulsets
daemonsets
deploymentconfigs
```

También se debe confirmar:

```text
FAILURE_POLICY=Ignore
```

### 7.4 Confirmar que el webhook continúa detenido

```bash
oc get deployment instana-autotrace-webhook \
  -n instana-autotrace-webhook
```

Debe continuar en:

```text
0/0
```

Si los valores Helm no muestran `false`, si aparecen recursos superiores o si existen configuraciones duplicadas, no continuar con los siguientes pasos.

---

## 8. Habilitar el webhook de forma controlada

Levantar una sola réplica mediante Helm:

```bash
helm upgrade instana-autotrace-webhook instana-autotrace-webhook \
  --namespace instana-autotrace-webhook \
  --repo https://agents.instana.io/helm \
  --version 1.320.12 \
  --reuse-values \
  --set webhook.deployment.replicas=1
```

Esperar que el deployment quede disponible:

```bash
oc rollout status deployment/instana-autotrace-webhook \
  -n instana-autotrace-webhook \
  --timeout=5m
```

Validar el pod:

```bash
oc get pods \
  -n instana-autotrace-webhook \
  -l app.kubernetes.io/name=instana-autotrace-webhook \
  -o wide
```

Resultado esperado:

```text
READY   STATUS
1/1     Running
```

Confirmar la imagen:

```bash
oc get pods \
  -n instana-autotrace-webhook \
  -l app.kubernetes.io/name=instana-autotrace-webhook \
  -o jsonpath='{range .items[*]}{.metadata.name}{" => "}{.spec.containers[0].image}{"\n"}{end}'
```

Resultado esperado:

```text
containers.instana.io/instana/release/agent/instana-autotrace-webhook:1.320.12
```

Validar que el servicio tenga un endpoint activo:

```bash
oc get endpoints instana-autotrace-webhook \
  -n instana-autotrace-webhook
```

Revisar los logs iniciales:

```bash
oc logs deployment/instana-autotrace-webhook \
  -n instana-autotrace-webhook \
  --since=5m
```

No deben presentarse errores de TLS, certificados, conectividad o inicialización.

---

## 9. Validaciones previas sobre ACE

### 9.1 Confirmar el deployment objetivo

```bash
oc get deployment ace-gestionpronaca-ibm-ace-server-icp4i-prod \
  -n middleware
```

Confirmar versión y metadatos:

```bash
oc get deployment ace-gestionpronaca-ibm-ace-server-icp4i-prod \
  -n middleware \
  -o jsonpath='Product={.spec.template.metadata.annotations.productName}{"\n"}Version={.spec.template.metadata.annotations.productVersion}{"\n"}CloudPak={.spec.template.metadata.annotations.cloudpakName}{"\n"}CloudPakVersion={.spec.template.metadata.annotations.cloudpakVersion}{"\n"}Image={.spec.template.spec.containers[0].image}{"\n"}Replicas={.spec.replicas}{"\n"}'
```

Resultado esperado:

```text
Product=IBM Cloud Pak for Integration - IBM App Connect Enterprise (Chargeable)
Version=11.0.0.9
CloudPak=IBM Cloud Pak for Integration
CloudPakVersion=2020.1.1
Image=cddnpro.pronaca.com/middleware/ace-gestionpronaca:2.0.54
Replicas=2
```

### 9.2 Validar que no exista una exclusión de AutoTrace

Revisar el namespace:

```bash
oc get namespace middleware \
  -o jsonpath='Namespace instana-autotrace={.metadata.labels.instana-autotrace}{"\n"}'
```

Revisar el deployment y su plantilla:

```bash
oc get deployment ace-gestionpronaca-ibm-ace-server-icp4i-prod \
  -n middleware \
  -o jsonpath='Deployment instana-autotrace={.metadata.labels.instana-autotrace}{"\n"}Pod template instana-autotrace={.spec.template.metadata.labels.instana-autotrace}{"\n"}'
```

Los valores pueden estar vacíos o en `true`, pero no deben mostrar:

```text
false
```

Con `opt_in=false`, no es necesario agregar ningún label.

### 9.3 Validar los nodos actuales de ACE

```bash
oc get pods \
  -n middleware \
  -l app.kubernetes.io/instance=ace-gestionpronaca \
  -o custom-columns='POD:.metadata.name,NODE:.spec.nodeName,IP:.status.podIP,STATUS:.status.phase'
```

### 9.4 Confirmar que existe un agente Instana en los nodos de ACE

```bash
oc get pods -A \
  -o custom-columns='NAMESPACE:.metadata.namespace,POD:.metadata.name,NODE:.spec.nodeName,STATUS:.status.phase' \
  | grep instana-agent
```

Comparar los nodos de ambas salidas. Cada nodo donde se ejecute ACE debe contar con un agente Instana operativo.

El ACE Tracing User Exit envía los spans al agente Instana en `localhost:42699` de forma predeterminada; por ello, la presencia del agente en el mismo nodo es una validación necesaria.

---

## 10. Reiniciar únicamente el deployment ACE

Durante esta etapa no deben ejecutarse reinicios masivos ni despliegues paralelos.

Reiniciar únicamente el deployment seleccionado:

```bash
oc rollout restart \
  deployment/ace-gestionpronaca-ibm-ace-server-icp4i-prod \
  -n middleware
```

Esperar el resultado:

```bash
oc rollout status \
  deployment/ace-gestionpronaca-ibm-ace-server-icp4i-prod \
  -n middleware \
  --timeout=15m
```

Revisar los pods nuevos:

```bash
oc get pods \
  -n middleware \
  -l app.kubernetes.io/instance=ace-gestionpronaca \
  -o wide
```

No es necesario eliminar el deployment, borrar ReplicaSets ni agregar etiquetas.

---

## 11. Validar que el webhook instrumentó los pods

### 11.1 Validar labels de AutoTrace

```bash
oc get pods \
  -n middleware \
  -l app.kubernetes.io/instance=ace-gestionpronaca \
  -o custom-columns='POD:.metadata.name,APPLIED:.metadata.labels.instana-autotrace-applied,VERSION:.metadata.labels.instana-autotrace-version,NODE:.spec.nodeName,STATUS:.status.phase'
```

Resultado esperado:

```text
APPLIED   VERSION
true      1.320.12
```

### 11.2 Validar el init container

```bash
oc get pods \
  -n middleware \
  -l app.kubernetes.io/instance=ace-gestionpronaca \
  -o jsonpath='{range .items[*]}{"POD: "}{.metadata.name}{"\n"}{range .spec.initContainers[*]}{"  INIT: "}{.name}{" => "}{.image}{"\n"}{end}{end}'
```

Debe aparecer un init container que utilice:

```text
icr.io/instana/instrumentation:1.320.12
```

### 11.3 Validar el estado del init container

```bash
oc get pods \
  -n middleware \
  -l app.kubernetes.io/instance=ace-gestionpronaca \
  -o jsonpath='{range .items[*]}{"POD: "}{.metadata.name}{"\n"}{range .status.initContainerStatuses[*]}{"  INIT: "}{.name}{" READY="}{.ready}{" REASON="}{.state.terminated.reason}{"\n"}{end}{end}'
```

Resultado esperado:

```text
REASON=Completed
```

### 11.4 Validar volumen y montaje

```bash
oc get pods \
  -n middleware \
  -l app.kubernetes.io/instance=ace-gestionpronaca \
  -o yaml | grep -A6 -B6 -E \
  'instana-instrumentation|/opt/instana/instrumentation'
```

### 11.5 Revisar eventos

```bash
oc get events \
  -n middleware \
  --sort-by=.lastTimestamp | tail -40
```

No deben aparecer errores relacionados con:

```text
ImagePullBackOff
ErrImagePull
FailedCreate
FailedMount
SCC
permission denied
```

### 11.6 Revisar los logs del webhook

```bash
oc logs deployment/instana-autotrace-webhook \
  -n instana-autotrace-webhook \
  --since=15m | grep -E \
  'ace-gestionpronaca|Applied|ignored|ERROR|WARN'
```

Se espera un mensaje de transformación aplicada al pod.

No debería continuar apareciendo únicamente:

```text
looks like an instance of some higher-order resource
```

---

## 12. Validación funcional de trazas

El reinicio de los pods no genera trazas por sí solo. Se debe ejecutar tráfico real sobre los flujos publicados por ACE.

El ACE Tracing User Exit soporta flujos cuyo punto de entrada utiliza nodos compatibles, entre ellos:

- HTTP Input / HTTP Request, según el flujo implementado.
- IBM MQ.
- Kafka.

Después de generar tráfico, validar en Instana:

```text
Applications > Services
```

Para el User Exit de ACE, el nombre del servicio normalmente contiene la IP del pod y el nombre del integration server.

También se pueden revisar archivos y logs relacionados con la instrumentación:

```bash
for POD in $(oc get pods \
  -n middleware \
  -l app.kubernetes.io/instance=ace-gestionpronaca \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
do
  echo
  echo "===== $POD ====="
  oc exec -n middleware "$POD" \
    -c ace-gestionpronaca-ibm-ace-server-icp4i-prod -- \
    sh -c 'find /opt/instana/instrumentation -maxdepth 4 -type f 2>/dev/null | head -50'
done
```

Después de ejecutar transacciones, revisar el directorio de logs del User Exit:

```bash
for POD in $(oc get pods \
  -n middleware \
  -l app.kubernetes.io/instance=ace-gestionpronaca \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
do
  echo
  echo "===== $POD ====="
  oc exec -n middleware "$POD" \
    -c ace-gestionpronaca-ibm-ace-server-icp4i-prod -- \
    sh -c 'ls -la /tmp/trace 2>/dev/null; tail -100 /tmp/trace/* 2>/dev/null'
done
```

---

## 13. Qué validar si continúa el mensaje `higher-order resource`

Si el webhook continúa ignorando el pod después de confirmar:

```yaml
autotrace:
  enableHigherLevelResourceMutation: false
```

no realizar más reinicios de ACE. Detener nuevamente el webhook y recolectar evidencias.

### 13.1 Detener el webhook mediante Helm

```bash
helm upgrade instana-autotrace-webhook instana-autotrace-webhook \
  --namespace instana-autotrace-webhook \
  --repo https://agents.instana.io/helm \
  --version 1.320.12 \
  --reuse-values \
  --set webhook.deployment.replicas=0
```

### 13.2 Confirmar valores efectivos

```bash
helm get values instana-autotrace-webhook \
  -n instana-autotrace-webhook \
  --all > autotrace-backup/diagnostico-values.yaml
```

```bash
grep -A4 -B3 -E \
  'opt_in:|enableHigherLevelResourceMutation|failurePolicy|ace:|replicas:' \
  autotrace-backup/diagnostico-values.yaml
```

### 13.3 Comparar el manifiesto Helm con el objeto real

```bash
helm get manifest instana-autotrace-webhook \
  -n instana-autotrace-webhook \
  > autotrace-backup/diagnostico-manifest.yaml
```

```bash
grep -nE \
  'deployments|replicasets|statefulsets|daemonsets|deploymentconfigs|pods|configmaps' \
  autotrace-backup/diagnostico-manifest.yaml
```

Respaldar nuevamente el objeto real:

```bash
oc get mutatingwebhookconfiguration instana-autotrace-webhook \
  -o yaml > autotrace-backup/diagnostico-mwc-real.yaml
```

### 13.4 Revisar configuraciones duplicadas

```bash
oc get mutatingwebhookconfiguration -o name | grep -i instana
```

### 13.5 Revisar el servicio y el endpoint que atendían las solicitudes

```bash
oc get service instana-autotrace-webhook \
  -n instana-autotrace-webhook \
  -o yaml > autotrace-backup/diagnostico-service.yaml
```

```bash
oc get endpoints instana-autotrace-webhook \
  -n instana-autotrace-webhook \
  -o yaml > autotrace-backup/diagnostico-endpoints.yaml
```

### 13.6 Revisar la imagen y fecha del pod activo

Ejecutar esta validación después de volver a levantar temporalmente el webhook, solo si se requiere continuar con el diagnóstico:

```bash
oc get pods \
  -n instana-autotrace-webhook \
  -l app.kubernetes.io/name=instana-autotrace-webhook \
  -o custom-columns='POD:.metadata.name,CREATED:.metadata.creationTimestamp,IMAGE:.spec.containers[0].image,NODE:.spec.nodeName,STATUS:.status.phase'
```

### Interpretación

| Resultado | Diagnóstico |
|---|---|
| Helm muestra `false`, pero la configuración real contiene `deployments` o `replicasets` | La `MutatingWebhookConfiguration` no fue actualizada o existe un objeto residual. |
| Existen dos configuraciones de Instana | Una configuración anterior puede estar atendiendo solicitudes. |
| Las reglas reales incluyen únicamente `pods` y `configmaps`, pero el log continúa indicando `higher-order resource` | Debe recopilarse el manifiesto, logs y endpoints para revisión con soporte IBM. |
| El pod tiene `instana-autotrace-applied=true`, pero no hay trazas | El webhook ya funcionó; se debe revisar el init container, User Exit, tráfico, nodo del agente y limitaciones de ACE. |
| El init container queda en `ImagePullBackOff` | Revisar acceso de los nodos a `icr.io/instana/instrumentation:1.320.12` o utilizar una imagen replicada en el registro interno. |
| El init container falla por permisos o SCC | Revisar los eventos del pod y el `securityContext` inyectado. |
| ACE se ejecuta en un nodo sin agente Instana | Corregir la cobertura del DaemonSet o la ubicación del pod ACE antes de validar trazas. |

---

## 14. Procedimiento de reversa

### 14.1 Detener el webhook

```bash
helm upgrade instana-autotrace-webhook instana-autotrace-webhook \
  --namespace instana-autotrace-webhook \
  --repo https://agents.instana.io/helm \
  --version 1.320.12 \
  --reuse-values \
  --set webhook.deployment.replicas=0
```

Confirmar:

```bash
oc get deployment instana-autotrace-webhook \
  -n instana-autotrace-webhook
```

### 14.2 Volver a crear los pods ACE sin instrumentación

Debido a que `failurePolicy=Ignore`, OpenShift permitirá la creación de pods aun cuando el webhook esté detenido:

```bash
oc rollout restart \
  deployment/ace-gestionpronaca-ibm-ace-server-icp4i-prod \
  -n middleware
```

```bash
oc rollout status \
  deployment/ace-gestionpronaca-ibm-ace-server-icp4i-prod \
  -n middleware \
  --timeout=15m
```

Validar que los pods nuevos ya no tengan el label:

```bash
oc get pods \
  -n middleware \
  -l app.kubernetes.io/instance=ace-gestionpronaca \
  -o custom-columns='POD:.metadata.name,APPLIED:.metadata.labels.instana-autotrace-applied,VERSION:.metadata.labels.instana-autotrace-version,STATUS:.status.phase'
```

No se requiere retirar labels del deployment porque la validación mantiene `opt_in=false` y no agrega etiquetas manuales.

---

## 15. Consideraciones de soporte

### Versión del clúster

El AutoTrace Webhook requiere Kubernetes `1.16+` u OpenShift `4.5+`. El ambiente con Kubernetes `1.20` y OpenShift `4.7` cumple el prerrequisito mínimo publicado.

### Versión de ACE

ACE `11.0.0.9` se encuentra dentro del rango compatible con el Instana ACE Tracing User Exit.

### Imagen personalizada

El deployment utiliza:

```text
cddnpro.pronaca.com/middleware/ace-gestionpronaca:2.0.54
```

Aunque mantiene metadatos de Cloud Pak for Integration, corresponde confirmar que esta imagen conserva la estructura de la imagen certificada de ACE. Si el webhook modifica el pod, pero no instala los componentes específicos de ACE, este punto deberá revisarse.

### Número de réplicas

El deployment tiene dos réplicas:

```yaml
replicas: 2
```

IBM documenta el método ACE Tracing User Exit para configuraciones single-node y señala que los esquemas HA o clusterizados no están soportados por este mecanismo. Esta condición no causa el mensaje `higher-order resource`, pero debe revisarse antes de considerar la solución de trazas como plenamente soportada.

No se recomienda reducir réplicas en producción sin una evaluación y aprobación previa del cliente.

### Ciclo de vida

El soporte del AutoTrace Webhook para IBM ACE está deprecado y tiene fecha de fin de soporte el `31 de mayo de 2027`. Para una evolución futura, IBM recomienda utilizar el tracing nativo basado en OpenTelemetry disponible en versiones más recientes de ACE.

---

## 16. Resultado esperado

La validación será satisfactoria cuando se confirme:

```text
Webhook 1.320.12 Running
enableHigherLevelResourceMutation=false
opt_in=false
MutatingWebhookConfiguration aplicada a pods y ConfigMaps
Pod ACE con instana-autotrace-applied=true
Init container de instrumentación en Completed
Agente Instana presente en el nodo ACE
Tráfico real visible como trazas en Instana
```

---

## Referencias

- [IBM Docs - Configuring AutoTrace webhook](https://www.ibm.com/docs/en/instana-observability?topic=webhook-configuring-autotrace)
- [IBM Docs - Instana AutoTrace webhook](https://www.ibm.com/docs/en/instana-observability?topic=kubernetes-instana-autotrace-webhook)
- [IBM Docs - Configuring IBM App Connect Enterprise Tracer](https://www.ibm.com/docs/en/instana-observability?topic=ace-configuring-tracing-in)
- [IBM Docs - Supported versions and operating systems for IBM ACE Tracing](https://www.ibm.com/docs/en/instana-observability?topic=ace-supported-versions-platforms)
- [Instana GitHub - AutoTrace Webhook](https://github.com/instana/instana-autotrace-webhook)

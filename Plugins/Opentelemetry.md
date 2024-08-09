# Habilitación de Opentelemetry en Agente Instana


## Plataforma Windows, Linux , UNIX
1. Ingresar al archivo de configuración del agente Instana

   Windows

       C:\Program Files\Instana\instana-agent\etc\instana

   Linux / Unix

       /opt/instana/agent/etc/instana/

2. Ubicar las lineas para el plugin de Opentelemetry en el archivo configuracion.yaml.

       configuration.yaml

3. Descomentar las lineas del plugin Opentelemetry y realizar las modificaciones de acuerdo con el ambiente a configurar.

       com.instana.plugin.opentelemetry:
         grpc:
           enabled: true
         http:
           enabled: true

4. Reiniciar el agente Instana.

   Windows: Abrir ventana de linea de comandos y ejecutar los siguiente comandos.

       net stop instana-agent-service
       net start instana-agent-service

     Ejemplo de ejecucion:
  
     ![image](https://github.com/user-attachments/assets/0f090093-e0a9-4e7e-beda-27ca7569e87f)


   Linux: Ejecutar los siguientes comandos.

       systemctl stop instana-agent
       systemctl start instana-agent
       systemctl status instana-agent

     Ejemplo de ejecucion:

     ![image](https://github.com/user-attachments/assets/2a0bf697-810e-49d9-9e59-8526dc5f9d18)

     

   Unix

       cd  /opt/instana-agent/bin/
       ./stop
       ./start
       ./status
     

     Ejemplo de ejecucion:

     ![image](https://github.com/user-attachments/assets/37abf03b-f491-4ead-8287-3394bf337872)


   


## Plataforma Openshift (oc) / Kubernetes (kubectl)

1. Ingresar al proyecto instana-agent donde se desplegaron los componentes de Instana.

       oc project instana-agent

2. Editar el configmap instana-agent, agregar las lineas del sensor para Opentelemetry respetando la indentación del formato yaml y guardar los cambios.

   Ejecutar los siguientes comandos:
   
       oc get cm
       oc edit cm instana-agent   

   Líneas del sensor Opentelemetry:

       com.instana.plugin.opentelemetry:
         grpc:
           enabled: true
         http:
           enabled: true       


   Ejemplo de ejecución:

   ![image](https://github.com/user-attachments/assets/41da6ab1-4356-4f7e-b7d5-3400e83d3459)
 
   ![image](https://github.com/user-attachments/assets/b4fd8455-4c44-4eda-b454-5962941b2a7f)

   ![image](https://github.com/user-attachments/assets/5525641e-2bac-45cf-aba6-6ad139ddb87b)

   ![image](https://github.com/user-attachments/assets/8ce591c5-e334-488a-8af7-a5f8bc50412e)

4. Reiniciar el daemonset del agente Instana para aplicar los cambios.

   Ejecutar el siguiente comando:
   
       oc rollout restart ds instana-agent
   
5. Listar los pods y verificar que han sido recreados. (Puede tardar aproximandamente 5 minutos en recrear todos los pods)

   Ejecutar el siguiente comando:
   
       oc get pods

   Ejemplo de ejecución:

   ![image](https://github.com/user-attachments/assets/6ec43832-b4e8-48e0-a0ad-f7c8305436c2)

6. Editar el servicio del agente Instana y agregar los puertos asociados a opentelemetry 4317 - 4318 respetando la indentación del formato yaml y guardar los cambios.

   Ejecutar los siguientes comando:
   
       oc get svc
       oc edit svc instana-agent

   Líneas para los puertos de Opentelemetry:

       - name: opentelemetry
         port: 55680
         protocol: TCP
         targetPort: 55680
       - name: opentelemetry-iana
         port: 4317
         protocol: TCP
         targetPort: 4317
       - name: opentelemetry-http
         port: 4318
         protocol: TCP
         targetPort: 4318
   
   Ejemplo de ejecución:

   ![image](https://github.com/user-attachments/assets/e0c3f836-0eee-4c0c-89cc-a2c90cde5acb)

   ![image](https://github.com/user-attachments/assets/59601ffe-5bac-4bdb-aa33-9d7aeeddc985)

   ![image](https://github.com/user-attachments/assets/1d26b937-2434-4e41-9b1a-a4ff1e35c82a)

   ![image](https://github.com/user-attachments/assets/932894e0-693f-4e1d-ae9a-d4be160fe7bf)


7. Verificar que los puertos agregados se encuentren publicados a nivel del servicio.

   Ejecutar el siguiente comando:
   
       oc get svc
   
   Ejemplo de ejecución:

   ![image](https://github.com/user-attachments/assets/77303b77-0644-4943-8c0e-4c99648977e7)




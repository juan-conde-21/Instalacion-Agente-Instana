# Habilitación de Plugin Java Trace SDK

1. Ingresar al archivo de configuración del agente Instana

   Windows

       C:\Program Files\Instana\instana-agent\etc\instana\configuration.yaml

   Linux

       /opt/instana/agent/etc/instana/configuration.yaml

2. Ubicar las lineas para el plugin de Java Trace SDK en el archivo de configuracion.

   ![image](https://github.com/user-attachments/assets/95b81b13-559a-4e50-86d7-925f70a0ed6d)

3. Proceder a modificar colocando el nombre del paquete donde se realizó la instrumentación con el sdk para java de Instana y guardar los cambios. Para este ejemplo se utiliza el paquete "com.example.hello_spring"

   Lineas de configuracion:

       # Java Tracing
       com.instana.plugin.javatrace:
         instrumentation:
           sdk:
             packages:
               - 'com.example.hello_spring'
       #    # Lightweight Bytecode Instrumentation, enabled by default
       #    # Disabling currently requires an agent restart
           enabled: true

4. Reiniciar el agente Instana desde linea de comandos.

   Windows

       net stop "instana-agent-service"
       net start "instana-agent-service"

   Linux

       systemctl stop instana-agent
       systemctl start instana-agent


# Captura de metadatos mediante Java Trace SDK

1. Añadir la dependencia del SDK de Instana en el archivo pom.xml del proyecto java.

       <dependency>
         <groupId>com.instana</groupId>
         <artifactId>instana-java-sdk</artifactId>
         <version>1.2.0</version>
       </dependency>

2. Importa las clases del Java Trace SDK de Instana en la clase donde se realizará la instrumentación de los métodos, con el fin de capturar la metadata adicional deseada.

       import com.instana.sdk.annotation.Span;
       import com.instana.sdk.support.SpanSupport;


3. Agregar las lineas para captura de metadata en los metodos requeridos, se utilizará el método "SpanSupport.annotate".


       @GetMapping("/sum")
       public String sum(@RequestParam(value = "a", defaultValue = "0") int a,
                         @RequestParam(value = "b", defaultValue = "0") int b) {
           int result = a + b;
   
           SpanSupport.annotate("tags.id_seguro", "" + a);
           SpanSupport.annotate("tags.value_b", "" + b);
   
           return "la suma es " + result;
       }

4. Se muestra un ejemplo de instrumentación.

   ![image](https://github.com/user-attachments/assets/ddfffb0b-7fcc-44a7-a9fe-85f1ca04ea08)


5. Ejemplo de captura en Instana.

   ![image](https://github.com/user-attachments/assets/ce512998-eda8-445d-9e36-1c6500309e41)

6. Ejemplo de uso con filtros en la seccion de analitica de Instana.

   ![image](https://github.com/user-attachments/assets/7632791e-c2fb-4f4e-8e58-79fdc2b50074)

 7. Aplicacion demo utilizada [hello-spring](Plugins/Java_Trace_SDK/hello-spring)  






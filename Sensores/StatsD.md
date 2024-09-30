# Habilitación de Sensor StatsD

1. Ingresar al archivo de configuración del agente Instana

   Windows

       C:\Program Files\Instana\instana-agent\etc\instana

   Linux

       /opt/instana/agent/etc/instana/

2. Ubicar las lineas para el sensor de statsd en el archivo de configuracion, modificar y guardar los cambios.

   ![image](https://github.com/user-attachments/assets/0522fb2e-75e6-4c37-95e3-109887972d39)

   Lineas de configuracion:

       # StatsD
       com.instana.plugin.statsd:
         enabled: true
         ports:
           udp: 8125
           mgmt: 8126
         bind-ip: "0.0.0.0" # all ips by default
         flush-interval: 10 # in seconds

3. El sensor de Statsd soporta la recepcion de datos por el puerto 8125, por ejemplo los datos serian enviados de la siguiente manera:

        echo -n "custom.metric.name-test:1|c" | 34.135.37.172 8125

   La estructura es la siguiente:

    {nombre de metrica}:{valor de metrica}|{tipo de metrica} 
   
   Tipos de metrica soportados:

    c: Counting
    ms: Timing
    g: Gauges
    s: Sets
   
    Referencia: https://github.com/statsd/statsd/blob/master/docs/metric_types.md

4. Script de ejemplo en bash para envio de metricas en servidor Linux local:


       !/bin/bash
        
       # Configuración del endpoint StatsD
       HOST="localhost"
       PORT="8125"
       DB_INSTANCES=("db_instance_1" "db_instance_2" "db_instance_3")
        
       # Función para enviar métricas
       enviar_metricas() {
         while true; do
           for DB_INSTANCE in "${DB_INSTANCES[@]}"; do
             # Generar métricas de ejemplo
             BUFFERPOOL_HITRATIO=$(awk -v min=70 -v max=100 'BEGIN{srand(); print min+rand()*(max-min)}')
             LOCK_WAIT_TIME=$(shuf -i 0-100 -n 1)
             DEADLOCKS=$(shuf -i 0-5 -n 1)
             CONNECTIONS_ACTIVE=$(shuf -i 50-100 -n 1)
             TRANSACTIONS_COMMITTED=$(shuf -i 1000-5000 -n 1)
             TRANSACTIONS_ROLLED_BACK=$(shuf -i 10-100 -n 1)
             QUERY_EXECUTION_TIME=$(awk -v min=0.01 -v max=1.0 'BEGIN{srand(); print min+rand()*(max-min)}')
             QUERY_EXECUTION_TIME_MS=$(echo "$QUERY_EXECUTION_TIME * 1000" | bc)
       
             # Enviar métricas usando netcat con etiquetas
             echo "db2.bufferpool.hitrate:${BUFFERPOOL_HITRATIO}|g|#instance:${DB_INSTANCE}" | nc -u -w 1 $HOST $PORT
             echo "db2.lock.wait_time:${LOCK_WAIT_TIME}|ms|#instance:${DB_INSTANCE}" | nc -u -w 1 $HOST $PORT
             echo "db2.deadlocks:${DEADLOCKS}|g|#instance:${DB_INSTANCE}" | nc -u -w 1 $HOST $PORT
             echo "db2.connections.active:${CONNECTIONS_ACTIVE}|g|#instance:${DB_INSTANCE}" | nc -u -w 1 $HOST $PORT
             echo "db2.transactions.committed:${TRANSACTIONS_COMMITTED}|g|#instance:${DB_INSTANCE}" | nc -u -w 1 $HOST $PORT
             echo "db2.transactions.rolled_back:${TRANSACTIONS_ROLLED_BACK}|g|#instance:${DB_INSTANCE}" | nc -u -w 1 $HOST $PORT
             echo "db2.query.execution_time:${QUERY_EXECUTION_TIME_MS}|ms|#instance:${DB_INSTANCE}" | nc -u -w 1 $HOST $PORT
        
             echo "Enviado para ${DB_INSTANCE}: Buffer Pool Hit Ratio=${BUFFERPOOL_HITRATIO}%, Lock Wait Time=${LOCK_WAIT_TIME}ms, Deadlocks=${DEADLOCKS}, Conexiones Activas=${CONNECTIONS_ACTIVE}, Transacciones Completadas=${TRANSACTIONS_COMMITTED}, Transacciones Revertidas=${TRANSACTIONS_ROLLED_BACK}, Tiempo de Ejecución de Consulta=${QUERY_EXECUTION_TIME}s"
           done
        
           # Esperar antes de enviar la siguiente métrica
           sleep 10
          done
       }
        
       # Ejecutar la función de envío de métricas
       enviar_metricas


5. Visualizacion de metricas ingestadas en Instana.

   ![image](https://github.com/user-attachments/assets/0c3ada60-4682-4096-8601-de00b861ce88)


6. Generacion de Dashboards con las metricas en Instana.

   ![image](https://github.com/user-attachments/assets/8764ed2a-f0ae-4342-9b4c-a8a4ab1c44ac)

   *Tambien es posible la creacion de alertas personalizadas en base a las metricas ingestadas.







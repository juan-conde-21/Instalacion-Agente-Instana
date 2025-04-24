


######## Archivo configuracion opentelemetry filelogreceiver config.yaml ##############



    receivers:
      filelog:
        include: [ "/opt/proceso/transacciones_ibk.dat" ]
        include_file_path: true
        start_at: beginning
        multiline:
          line_start_pattern: '.*:H:.*'
    
    exporters:
      debug:
        verbosity: detailed
      otlphttp:
        endpoint: http://127.0.0.1:4318
        tls:
          insecure: true
    
    service:
      pipelines:
        logs:
          receivers: [filelog]
          processors: []
          exporters: [debug, otlphttp]










###################

mkdir /opt/instana-agent/otel-contrib

vi /etc/init.d/otelcol-contrib



################

    #!/bin/bash
    #
    # otelcol-contrib
    # Descripción: Servicio para iniciar OpenTelemetry Collector Contrib
    #
    # chkconfig: 2345 90 10
    # description: Inicia el agente otelcol-contrib con su configuración personalizada
    
    DAEMON="/opt/instana-agent/otel-contrib/otelcol-contrib"
    CONFIG="/opt/instana-agent/otel-contrib/config-super.yaml"
    PIDFILE="/var/run/otelcol-contrib.pid"
    LOGFILE="/var/log/otelcol-contrib.log"
    
    start() {
        echo "Iniciando otelcol-contrib..."
        if [ -f $PIDFILE ]; then
            echo "Ya está en ejecución (PID $(cat $PIDFILE))"
            exit 1
        fi
        nohup $DAEMON --config $CONFIG >> $LOGFILE 2>&1 &
        echo $! > $PIDFILE
        echo "Iniciado con PID $(cat $PIDFILE)"
    }
    
    stop() {
        echo "Deteniendo otelcol-contrib..."
        if [ -f $PIDFILE ]; then
            kill $(cat $PIDFILE) && rm -f $PIDFILE
            echo "Detenido."
        else
            echo "No está en ejecución."
        fi
    }
    
    status() {
        if [ -f $PIDFILE ]; then
            echo "En ejecución con PID $(cat $PIDFILE)"
        else
            echo "No está en ejecución."
        fi
    }
    
    case "$1" in
      start)
        start
        ;;
      stop)
        stop
        ;;
      restart)
        stop
        start
        ;;
      status)
        status
        ;;
      *)
        echo "Uso: $0 {start|stop|restart|status}"
        exit 1
    esac
    
    exit 0


################


chmod +x /etc/init.d/otelcol-contrib

chkconfig --add otelcol-contrib
chkconfig otelcol-contrib on


		/etc/init.d/otelcol-contrib start
/etc/init.d/otelcol-contrib stop
/etc/init.d/otelcol-contrib status


chmod +x /opt/instana-agent/otel-contrib/otelcol-contrib




################################# SERVICIO PYTHON  ###########


vi /opt/instana-agent/otel-contrib/instana-metric-logs.py

e insertar el contenido del script python instana-metric-logs.py

vi /etc/init.d/instana-metric-logs


#######

    #!/bin/bash
    #
    # instana-metric-logs
    # Descripción: Servicio para ejecutar script Python que envía métricas desde logs
    #
    # chkconfig: 2345 91 09
    # description: Ejecuta instana-metric-logs.py como servicio
    
    DAEMON="/usr/bin/python"
    SCRIPT="/opt/instana-agent/otel-contrib/instana-metric-logs.py"
    PIDFILE="/var/run/instana-metric-logs.pid"
    LOGFILE="/var/log/instana-metric-logs.log"
    
    start() {
        echo "Iniciando instana-metric-logs..."
        if [ -f $PIDFILE ]; then
            echo "Ya está en ejecución (PID $(cat $PIDFILE))"
            exit 1
        fi
        nohup $DAEMON $SCRIPT >> $LOGFILE 2>&1 &
        echo $! > $PIDFILE
        echo "Iniciado con PID $(cat $PIDFILE)"
    }
    
    stop() {
        echo "Deteniendo instana-metric-logs..."
        if [ -f $PIDFILE ]; then
            kill $(cat $PIDFILE) && rm -f $PIDFILE
            echo "Detenido."
        else
            echo "No está en ejecución."
        fi
    }
    
    status() {
        if [ -f $PIDFILE ]; then
            echo "En ejecución con PID $(cat $PIDFILE)"
        else
            echo "No está en ejecución."
        fi
    }
    
    case "$1" in
      start)
        start
        ;;
      stop)
        stop
        ;;
      restart)
        stop
        start
        ;;
      status)
        status
        ;;
      *)
        echo "Uso: $0 {start|stop|restart|status}"
        exit 1
    esac
    
    exit 0


#######

chmod +x /etc/init.d/instana-metric-logs

chkconfig --add instana-metric-logs
chkconfig instana-metric-logs on


/etc/init.d/instana-metric-logs start
/etc/init.d/instana-metric-logs stop
/etc/init.d/instana-metric-logs restart



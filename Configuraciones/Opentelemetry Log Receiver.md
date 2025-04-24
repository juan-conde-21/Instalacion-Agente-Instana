


######## Archivo configuracion opentelemetry filelogreceiver config.yaml ##############



    receivers:
      filelog:
        include: [ "/opt/proceso/transacciones_ibk.dat" ]
        include_file_path: true
        start_at: beginning
        multiline:
          line_start_pattern: '.*:H:.*'
    
    processors:
      transform/logs:
        log_statements:
          - context: log
            statements:
              # Transacción clásica
              - 'set(cache, ExtractPatterns(body, "TDOC:\\s*(?P<TDOC>\\w+)"))'
              - 'set(attributes["TDOC"], cache["TDOC"])'
              - 'set(cache, ExtractPatterns(body, "NDOC:\\s*(?P<NDOC>\\d+)"))'
              - 'set(attributes["NDOC"], cache["NDOC"])'
              - 'set(cache, ExtractPatterns(body, "REINDR:\\s*(?P<REINDR>\\d+)"))'
              - 'set(attributes["REINDR"], cache["REINDR"])'
              - 'set(cache, ExtractPatterns(body, "NUMORD:\\s*(?P<NUMORD>\\d+)"))'
              - 'set(attributes["NUMORD"], cache["NUMORD"])'
              - 'set(cache, ExtractPatterns(body, "IDPGDR:\\s*(?P<IDPGDR>\\d+)"))'
              - 'set(attributes["IDPGDR"], cache["IDPGDR"])'
              - 'set(cache, ExtractPatterns(body, "CODAUT:\\s*(?P<CODAUT>\\w+)"))'
              - 'set(attributes["CODAUT"], cache["CODAUT"])'
              - 'set(cache, ExtractPatterns(body, "CANBNR:\\s*(?P<CANBNR>\\d+)"))'
              - 'set(attributes["CANBNR"], cache["CANBNR"])'
              - 'set(cache, ExtractPatterns(body, "OTHTIM:\\s*(?P<OTHTIM>\\d+)"))'
              - 'set(attributes["OTHTIM"], cache["OTHTIM"])'
    
              # Transacción extendida
              - 'set(cache, ExtractPatterns(body, "CODEUN:\\s*(?P<CODEUN>\\d+)"))'
              - 'set(attributes["CODEUN"], cache["CODEUN"])'
              - 'set(cache, ExtractPatterns(body, "SUNAT:\\s*(?P<SUNAT>\\d+)"))'
              - 'set(attributes["SUNAT"], cache["SUNAT"])'
              - 'set(cache, ExtractPatterns(body, "DTESER:\\s*(?P<DTESER>[\\w-]+)"))'
              - 'set(attributes["DTESER"], cache["DTESER"])'
              - 'set(cache, ExtractPatterns(body, "DTEDOC:\\s*(?P<DTEDOC>\\d+)"))'
              - 'set(attributes["DTEDOC"], cache["DTEDOC"])'
              - 'set(cache, ExtractPatterns(body, "DTEINA:\\s*(?P<DTEINA>\\d+)"))'
              - 'set(attributes["DTEINA"], cache["DTEINA"])'
              - 'set(cache, ExtractPatterns(body, "DTEGRA:\\s*(?P<DTEGRA>\\d+)"))'
              - 'set(attributes["DTEGRA"], cache["DTEGRA"])'
              - 'set(cache, ExtractPatterns(body, "DTEISC:\\s*(?P<DTEISC>\\d+)"))'
              - 'set(attributes["DTEISC"], cache["DTEISC"])'
              - 'set(cache, ExtractPatterns(body, "DTEIGV:\\s*(?P<DTEIGV>\\d+)"))'
              - 'set(attributes["DTEIGV"], cache["DTEIGV"])'
              - 'set(cache, ExtractPatterns(body, "POSSRN:\\s*(?P<POSSRN>[\\w-]+)"))'
              - 'set(attributes["POSSRN"], cache["POSSRN"])'
              - 'set(cache, ExtractPatterns(body, "CASNBR:\\s*(?P<CASNBR>\\d+)"))'
              - 'set(attributes["CASNBR"], cache["CASNBR"])'
    
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
          processors: [transform/logs]
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



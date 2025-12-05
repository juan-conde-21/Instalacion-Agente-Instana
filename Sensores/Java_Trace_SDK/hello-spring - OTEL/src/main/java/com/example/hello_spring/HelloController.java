package com.example.hellospring;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.client.RestTemplate;

import io.opentelemetry.api.trace.Span;



import io.opentelemetry.api.GlobalOpenTelemetry;
import io.opentelemetry.api.common.Attributes;
import io.opentelemetry.api.common.AttributeKey;
import io.opentelemetry.api.metrics.Meter;
import io.opentelemetry.api.metrics.DoubleCounter;


//import com.instana.sdk.annotation.Span;
//import com.instana.sdk.support.SpanSupport;


@RestController
public class HelloController {

    // --- MÉTRICAS OTel ---
    private static final Meter meter =
            GlobalOpenTelemetry.get().meterBuilder("hello-spring").build();

    private static final DoubleCounter transactionAmountTotal =
            meter.counterBuilder("transaction.amount.total")
                    .ofDoubles()
                    .setDescription("Monto total de transacciones procesadas")
                    .setUnit("USD") // o la unidad que uses
                    .build();

    private static final AttributeKey<String> ATTR_TYPE =
            AttributeKey.stringKey("transaction.type");
    private static final AttributeKey<String> ATTR_CURRENCY =
            AttributeKey.stringKey("transaction.currency");


    @GetMapping("/hello")
    public String hello() {
        return "hola";
    }

    @GetMapping("/sum")
    public String sum(@RequestParam(value = "a", defaultValue = "0") int a,
                      @RequestParam(value = "b", defaultValue = "0") int b) {
        int result = a + b;

		Span span = Span.current();
		if (span != null && span.getSpanContext().isValid()) {
			span.setAttribute("app.sum.a", a);
			span.setAttribute("app.sum.b", b);
			span.setAttribute("app.sum.c", "c");
			span.setAttribute("app.sum.d", "d");
			span.setAttribute("app.sum.e", "e");
			span.setAttribute("app.sum.f", "f");
			span.setAttribute("app.sum.g", "g");
			span.setAttribute("app.sum.h", "h");
			span.setAttribute("app.sum.i", "i");
			span.setAttribute("app.sum.result", result);
			span.setAttribute("app.sum.info", "suma de ejemplo con autoinstrumentación");
		}

		double amount = result;
        String type = "payment"; // ejemplo fijo, podrías sacarlo del request
        String currency = "USD";

        // 2) Métrica numérica: sumar el monto
        //    Estos atributos son etiquetas para agrupar (NO poner transactionId aquí).
        Attributes metricAttributes = Attributes.of(
                ATTR_TYPE, type,
                ATTR_CURRENCY, currency
        );

		transactionAmountTotal.add(amount, metricAttributes);


        //SpanSupport.annotate("tags.value_a", "" + a);
        //SpanSupport.annotate("tags.value_b", "" + b);
		//SpanSupport.annotate("tags.value_c", "c");
        //SpanSupport.annotate("tags.value_d", "d");
        //SpanSupport.annotate("tags.value_e", "e");
        //SpanSupport.annotate("tags.value_f", "f");
		//SpanSupport.annotate("tags.value_g", "g");
        //SpanSupport.annotate("tags.value_h", "h");
        //SpanSupport.annotate("tags.value_i", "i");
        //SpanSupport.annotate("tags.value_j", "j");
		//SpanSupport.annotate("tags.value_k", "k");
        //SpanSupport.annotate("tags.value_l", "l");
		//SpanSupport.annotate("tags.texto", "" + "Si superas las 20 llamadas por segundo utilizando el servicio web de trazas del Java Trace SDK de Instana, es probable que algunas de las solicitudes sean rechazadas o no procesadas correctamente. Esto puede resultar en la pérdida de datos de trazas, ya que el servicio no aceptará más de 20 solicitudes por segundo. El manejo exacto de este límite dependerá de cómo esté configurada la infraestructura de Instana y del comportamiento de la aplicación que realiza las llamadas. En algunos casos, podrías experimentar errores o excepciones en tu aplicación, lo que indicaría que las solicitudes adicionales están siendo bloqueadas o no están siendo enviadas.Para evitar problemas relacionados con este límite, se recomienda implementar un control de flujo en tu aplicación para asegurarse de que no se realicen más de 20 llamadas por segundo. Esto podría involucrar la agregación de múltiples spans en lotes más grandes o la reducción de la frecuencia de envío de datos.");

        return "la suma es " + result;
    }

    // Endpoint POST que recibe un JSON y consulta un servicio externo vía GET
    @PostMapping("/transaction")
    public String handleTransaction(@RequestBody TransactionRequest request) {
        // Simulación de consulta a un servicio externo con GET
        RestTemplate restTemplate = new RestTemplate();
        String externalServiceUrl = "https://start.spring.io/";
        ResponseEntity<String> response = restTemplate.getForEntity(externalServiceUrl, String.class);
        
        String transactionId = request.getTransactionId();
        double amount = request.getAmount();

        // Retornar la respuesta basada en la respuesta del servicio externo
        if (response.getStatusCode().is2xxSuccessful()) {

            //SpanSupport.annotate("tags.transactionID", "" + transactionId);
            //SpanSupport.annotate("tags.amount", "" + amount);

            return "transacción exitosa";
        } else {
            return "error en la transacción";
        }
    }
    
    // Clase interna para manejar el JSON de entrada
    public static class TransactionRequest {
        private String transactionId;
        private double amount;

        // Getters y setters
        public String getTransactionId() {
            return transactionId;
        }

        public void setTransactionId(String transactionId) {
            this.transactionId = transactionId;
        }

        public double getAmount() {
            return amount;
        }

        public void setAmount(double amount) {
            this.amount = amount;
        }
    }
}

package com.example.hellospring;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.client.RestTemplate;

import com.instana.sdk.annotation.Span;
import com.instana.sdk.support.SpanSupport;


@RestController
public class HelloController {

    @GetMapping("/hello")
    public String hello() {
        return "hola";
    }

    @GetMapping("/sum")
    public String sum(@RequestParam(value = "a", defaultValue = "0") int a,
                      @RequestParam(value = "b", defaultValue = "0") int b) {
        int result = a + b;

        SpanSupport.annotate("tags.id_seguro", "" + a);
        SpanSupport.annotate("tags.value_b", "" + b);

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

            SpanSupport.annotate("tags.transactionID", "" + transactionId);
            SpanSupport.annotate("tags.amount", "" + amount);

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

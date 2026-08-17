package com.ibm.demo.retail;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.nio.file.*;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.client.RestClient;

@SpringBootApplication
@RestController
public class RetailApplication {

    private static final Logger log =
        LoggerFactory.getLogger(RetailApplication.class);

    private static final Path CACHE =
        Paths.get("/opt/instana-demo/app/cache/promotions_current.csv");

    private static final Path VERSION_FILE =
        Paths.get("/opt/instana-demo/app/cache/promotions_current.version");

    private final RestClient restClient = RestClient.create();

    private final Map<String, Product> products =
        new ConcurrentHashMap<>();

    @Value("${demo.central.url}")
    private String centralUrl;

    @Value("${demo.max.age.seconds:120}")
    private long maxAgeSeconds;

    public static void main(String[] args) {
        SpringApplication.run(RetailApplication.class, args);
    }

    @GetMapping("/health")
    public Map<String,Object> health() {

        return Map.of(
            "status", "UP",
            "service", "retail-app",
            "timestamp", Instant.now().toString()
        );
    }

    @PostMapping("/api/sync")
    public ResponseEntity<Map<String,Object>> sync(
        @RequestParam String version
    ) {

        try {
            byte[] content = restClient
                .get()
                .uri(centralUrl + "/downloads/promotions_current.csv")
                .retrieve()
                .body(byte[].class);

            if (content == null || content.length == 0)
                throw new IllegalStateException("Downloaded file is empty");

            Files.createDirectories(CACHE.getParent());

            Path tmp =
                CACHE.getParent().resolve("promotions_current.csv.tmp");

            Files.write(
                tmp,
                content,
                StandardOpenOption.CREATE,
                StandardOpenOption.TRUNCATE_EXISTING
            );

            Map<String,Product> parsed =
                parseFile(tmp);

            if (parsed.size() < 100)
                throw new IllegalStateException(
                    "File contains too few records: " + parsed.size()
                );

            Files.move(
                tmp,
                CACHE,
                StandardCopyOption.REPLACE_EXISTING,
                StandardCopyOption.ATOMIC_MOVE
            );

            Files.writeString(
                VERSION_FILE,
                version,
                StandardOpenOption.CREATE,
                StandardOpenOption.TRUNCATE_EXISTING
            );

            products.clear();
            products.putAll(parsed);

            log.info(
                "event=file_loaded version={} records={} size_bytes={}",
                version,
                products.size(),
                content.length
            );

            return ResponseEntity.ok(
                Map.of(
                    "status", "READY",
                    "version", version,
                    "records", products.size(),
                    "sizeBytes", content.length
                )
            );

        } catch (Exception ex) {

            log.error(
                "event=file_load_failed version={} error={}",
                version,
                ex.toString()
            );

            return ResponseEntity
                .status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(
                    Map.of(
                        "status", "ERROR",
                        "error", ex.getMessage()
                    )
                );
        }
    }

    private Map<String,Product> parseFile(Path file) throws Exception {

        Map<String,Product> result =
            new HashMap<>();

        List<String> lines =
            Files.readAllLines(file);

        for (int i = 1; i < lines.size(); i++) {

            String line = lines.get(i);

            if (line.isBlank())
                continue;

            String[] p = line.split(",");

            if (p.length != 5)
                throw new IllegalArgumentException(
                    "Invalid CSV line " + (i + 1)
                );

            Product product = new Product(
                p[0],
                p[1],
                new BigDecimal(p[2]),
                new BigDecimal(p[3]),
                p[4]
            );

            result.put(product.sku(), product);
        }

        return result;
    }

    private long fileAgeSeconds() {

        try {
            if (!Files.exists(CACHE))
                return Long.MAX_VALUE;

            Instant modified =
                Files.getLastModifiedTime(CACHE).toInstant();

            return Math.max(
                0,
                Instant.now().getEpochSecond()
                - modified.getEpochSecond()
            );

        } catch (Exception ex) {
            return Long.MAX_VALUE;
        }
    }

    private String version() {

        try {
            if (Files.exists(VERSION_FILE))
                return Files.readString(VERSION_FILE).trim();
        } catch (Exception ignored) {}

        return "NONE";
    }

    @GetMapping("/api/status")
    public Map<String,Object> status() {

        long age = fileAgeSeconds();

        Map<String,Object> r =
            new LinkedHashMap<>();

        r.put("status", age <= maxAgeSeconds ? "READY" : "STALE");
        r.put("version", version());
        r.put("ageSeconds", age);
        r.put("maxAgeSeconds", maxAgeSeconds);
        r.put("records", products.size());

        return r;
    }

    @GetMapping("/api/operation/{sku}")
    public ResponseEntity<Map<String,Object>> operation(
        @PathVariable String sku
    ) {

        long age = fileAgeSeconds();

        if (age > maxAgeSeconds) {

            log.error(
                "event=operation_rejected reason=stale_file age_seconds={} version={}",
                age,
                version()
            );

            return ResponseEntity
                .status(HttpStatus.SERVICE_UNAVAILABLE)
                .body(
                    Map.of(
                        "status", "FAILED",
                        "reason", "PROMOTIONS_FILE_STALE",
                        "ageSeconds", age,
                        "version", version()
                    )
                );
        }

        Product p = products.get(sku);

        if (p == null)
            return ResponseEntity.notFound().build();

        BigDecimal discount =
            p.basePrice()
             .multiply(p.discountPct())
             .divide(BigDecimal.valueOf(100));

        BigDecimal finalPrice =
            p.basePrice()
             .subtract(discount)
             .setScale(2, RoundingMode.HALF_UP);

        log.info(
            "event=operation_success sku={} version={} final_price={}",
            sku,
            version(),
            finalPrice
        );

        Map<String,Object> response =
            new LinkedHashMap<>();

        response.put("status", "SUCCESS");
        response.put("sku", sku);
        response.put("product", p.name());
        response.put("basePrice", p.basePrice());
        response.put("discountPct", p.discountPct());
        response.put("finalPrice", finalPrice);
        response.put("version", version());

        return ResponseEntity.ok(response);
    }

    record Product(
        String sku,
        String name,
        BigDecimal basePrice,
        BigDecimal discountPct,
        String version
    ) {}
}

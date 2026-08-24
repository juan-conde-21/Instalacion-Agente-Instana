package com.ibm.demo.retail;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.nio.file.*;
import java.time.Instant;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentLinkedDeque;
import java.util.concurrent.atomic.AtomicLong;

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

    private static final DateTimeFormatter ORDER_TS =
        DateTimeFormatter
            .ofPattern("yyyyMMdd-HHmmss")
            .withZone(ZoneOffset.UTC);

    private final RestClient restClient =
        RestClient.create();

    private final Map<String, Product> products =
        new ConcurrentHashMap<>();

    private final Map<String, CustomerProfile> customerProfiles =
        createProfiles();

    private final Map<String, Deque<Map<String,Object>>> orders =
        new ConcurrentHashMap<>();

    private final AtomicLong orderSequence =
        new AtomicLong(1000);

    @Value("${demo.central.url}")
    private String centralUrl;

    @Value("${demo.max.age.seconds:120}")
    private long maxAgeSeconds;


    public static void main(String[] args) {

        SpringApplication.run(
            RetailApplication.class,
            args
        );

    }


    // ============================================================
    // TECHNICAL HEALTH
    // ============================================================

    @GetMapping("/health")
    public Map<String,Object> health() {

        return Map.of(
            "status", "UP",
            "service", "retail-app",
            "timestamp", Instant.now().toString()
        );

    }


    // ============================================================
    // COMMERCIAL INFORMATION SYNCHRONIZATION
    // ============================================================

    @PostMapping("/api/sync")
    public ResponseEntity<Map<String,Object>> sync(
        @RequestParam String version
    ) {

        try {

            byte[] content = restClient
                .get()
                .uri(
                    centralUrl +
                    "/downloads/promotions_current.csv"
                )
                .retrieve()
                .body(byte[].class);


            if (
                content == null ||
                content.length == 0
            ) {

                throw new IllegalStateException(
                    "Downloaded file is empty"
                );

            }


            Files.createDirectories(
                CACHE.getParent()
            );


            Path tmp =
                CACHE
                    .getParent()
                    .resolve(
                        "promotions_current.csv.tmp"
                    );


            Files.write(
                tmp,
                content,
                StandardOpenOption.CREATE,
                StandardOpenOption.TRUNCATE_EXISTING
            );


            Map<String,Product> parsed =
                parseFile(tmp);


            if (parsed.size() < 100) {

                throw new IllegalStateException(
                    "File contains too few records: " +
                    parsed.size()
                );

            }


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
                .status(
                    HttpStatus.INTERNAL_SERVER_ERROR
                )
                .body(
                    Map.of(
                        "status", "ERROR",
                        "error", ex.getMessage()
                    )
                );

        }

    }


    private Map<String,Product> parseFile(
        Path file
    ) throws Exception {

        Map<String,Product> result =
            new HashMap<>();


        List<String> lines =
            Files.readAllLines(file);


        for (
            int i = 1;
            i < lines.size();
            i++
        ) {

            String line =
                lines.get(i);


            if (line.isBlank()) {

                continue;

            }


            String[] p =
                line.split(",");


            if (p.length != 5) {

                throw new IllegalArgumentException(
                    "Invalid CSV line " +
                    (i + 1)
                );

            }


            Product product =
                new Product(
                    p[0],
                    p[1],
                    new BigDecimal(p[2]),
                    new BigDecimal(p[3]),
                    p[4]
                );


            result.put(
                product.sku(),
                product
            );

        }


        return result;

    }


    // ============================================================
    // COMMERCIAL DATA STATE
    // ============================================================

    private long fileAgeSeconds() {

        try {

            if (!Files.exists(CACHE)) {

                return Long.MAX_VALUE;

            }


            Instant modified =
                Files
                    .getLastModifiedTime(CACHE)
                    .toInstant();


            return Math.max(
                0,
                Instant.now().getEpochSecond()
                - modified.getEpochSecond()
            );


        } catch (Exception ex) {

            return Long.MAX_VALUE;

        }

    }


    private boolean commercialDataIsFresh() {

        return fileAgeSeconds()
            <= maxAgeSeconds;

    }


    private String version() {

        try {

            if (
                Files.exists(
                    VERSION_FILE
                )
            ) {

                return Files
                    .readString(
                        VERSION_FILE
                    )
                    .trim();

            }

        } catch (Exception ignored) {}


        return "NONE";

    }


    @GetMapping("/api/status")
    public Map<String,Object> status() {

        long age =
            fileAgeSeconds();


        Map<String,Object> response =
            new LinkedHashMap<>();


        response.put(
            "status",
            age <= maxAgeSeconds
                ? "READY"
                : "STALE"
        );

        response.put(
            "version",
            version()
        );

        response.put(
            "ageSeconds",
            age
        );

        response.put(
            "maxAgeSeconds",
            maxAgeSeconds
        );

        response.put(
            "records",
            products.size()
        );


        return response;

    }


    // ============================================================
    // NOVA CUSTOMER PROFILES
    // ============================================================

    private static Map<String,CustomerProfile>
    createProfiles() {

        Map<String,CustomerProfile> profiles =
            new LinkedHashMap<>();


        profiles.put(
            "valeria",
            new CustomerProfile(
                "valeria",
                "Valeria",
                "NOVA Club Plus",
                new BigDecimal("5")
            )
        );


        profiles.put(
            "diego",
            new CustomerProfile(
                "diego",
                "Diego",
                "NOVA Club",
                new BigDecimal("3")
            )
        );


        profiles.put(
            "invitado",
            new CustomerProfile(
                "invitado",
                "Invitado",
                "Sin membresía",
                BigDecimal.ZERO
            )
        );


        return Collections.unmodifiableMap(
            profiles
        );

    }


    @GetMapping("/api/profiles")
    public Collection<CustomerProfile>
    profiles() {

        return customerProfiles.values();

    }


    // ============================================================
    // CATALOG
    //
    // The catalog can still be viewed using the last loaded
    // commercial information. Checkout is the operation that
    // requires the information to be fresh.
    // ============================================================

    @GetMapping("/api/catalog")
    public Map<String,Object> catalog(
        @RequestParam(
            defaultValue = "4"
        ) int limit
    ) {

        int safeLimit =
            Math.max(
                1,
                Math.min(
                    limit,
                    24
                )
            );


        List<Map<String,Object>> items =
            products
                .values()
                .stream()
                .sorted(
                    Comparator.comparing(
                        Product::sku
                    )
                )
                .limit(safeLimit)
                .map(
                    this::catalogItem
                )
                .toList();


        Map<String,Object> response =
            new LinkedHashMap<>();


        response.put(
            "status",
            "SUCCESS"
        );

        response.put(
            "version",
            version()
        );

        response.put(
            "items",
            items
        );


        return response;

    }


    private Map<String,Object> catalogItem(
        Product product
    ) {

        Map<String,Object> item =
            new LinkedHashMap<>();


        item.put(
            "sku",
            product.sku()
        );

        item.put(
            "product",
            product.name()
        );

        item.put(
            "basePrice",
            money(
                product.basePrice()
            )
        );

        item.put(
            "promotionPct",
            money(
                product.discountPct()
            )
        );

        item.put(
            "promotionPrice",
            promotionPrice(
                product
            )
        );


        return item;

    }


    // ============================================================
    // CHECKOUT
    // ============================================================

    @PostMapping("/api/checkout")
    public ResponseEntity<Map<String,Object>>
    checkout(
        @RequestBody CheckoutRequest request
    ) {

        if (
            request == null ||
            request.userId() == null ||
            request.userId().isBlank()
        ) {

            return businessError(
                HttpStatus.BAD_REQUEST,
                "INVALID_CUSTOMER",
                "Customer profile is required"
            );

        }


        String userId =
            request
                .userId()
                .trim()
                .toLowerCase(
                    Locale.ROOT
                );


        CustomerProfile profile =
            customerProfiles.get(
                userId
            );


        if (profile == null) {

            return businessError(
                HttpStatus.BAD_REQUEST,
                "INVALID_CUSTOMER",
                "Unknown customer profile"
            );

        }


        if (
            request.items() == null ||
            request.items().isEmpty()
        ) {

            return businessError(
                HttpStatus.BAD_REQUEST,
                "EMPTY_CART",
                "Cart is empty"
            );

        }


        if (!commercialDataIsFresh()) {

            long age =
                fileAgeSeconds();


            log.error(
                "event=checkout_rejected user={} tier={} reason=stale_commercial_data age_seconds={} version={}",
                userId,
                profile.tier(),
                age,
                version()
            );


            Map<String,Object> body =
                new LinkedHashMap<>();


            body.put(
                "status",
                "FAILED"
            );

            body.put(
                "reason",
                "COMMERCIAL_DATA_STALE"
            );

            body.put(
                "ageSeconds",
                age
            );

            body.put(
                "version",
                version()
            );


            return ResponseEntity
                .status(
                    HttpStatus.SERVICE_UNAVAILABLE
                )
                .body(body);

        }


        BigDecimal subtotal =
            BigDecimal.ZERO;

        BigDecimal promotionSavings =
            BigDecimal.ZERO;

        BigDecimal clubSavings =
            BigDecimal.ZERO;

        BigDecimal total =
            BigDecimal.ZERO;

        int itemCount =
            0;


        List<Map<String,Object>> lines =
            new ArrayList<>();


        for (
            CheckoutItemRequest requestedItem :
            request.items()
        ) {

            if (
                requestedItem == null ||
                requestedItem.sku() == null ||
                requestedItem.sku().isBlank() ||
                requestedItem.quantity() == null ||
                requestedItem.quantity() < 1 ||
                requestedItem.quantity() > 10
            ) {

                return businessError(
                    HttpStatus.BAD_REQUEST,
                    "INVALID_CART_ITEM",
                    "Invalid cart item"
                );

            }


            String sku =
                requestedItem
                    .sku()
                    .trim()
                    .toUpperCase(
                        Locale.ROOT
                    );


            Product product =
                products.get(sku);


            if (product == null) {

                return businessError(
                    HttpStatus.NOT_FOUND,
                    "PRODUCT_NOT_FOUND",
                    sku
                );

            }


            int quantity =
                requestedItem.quantity();


            BigDecimal baseUnit =
                money(
                    product.basePrice()
                );


            BigDecimal promotionUnit =
                promotionPrice(
                    product
                );


            BigDecimal clubDiscountUnit =
                promotionUnit
                    .multiply(
                        profile.clubDiscountPct()
                    )
                    .divide(
                        BigDecimal.valueOf(100),
                        6,
                        RoundingMode.HALF_UP
                    );


            BigDecimal finalUnit =
                money(
                    promotionUnit.subtract(
                        clubDiscountUnit
                    )
                );


            BigDecimal qty =
                BigDecimal.valueOf(
                    quantity
                );


            BigDecimal lineBase =
                money(
                    baseUnit.multiply(qty)
                );


            BigDecimal linePromotionTotal =
                money(
                    promotionUnit.multiply(qty)
                );


            BigDecimal lineFinal =
                money(
                    finalUnit.multiply(qty)
                );


            BigDecimal linePromotionSavings =
                money(
                    lineBase.subtract(
                        linePromotionTotal
                    )
                );


            BigDecimal lineClubSavings =
                money(
                    linePromotionTotal.subtract(
                        lineFinal
                    )
                );


            subtotal =
                subtotal.add(
                    lineBase
                );


            promotionSavings =
                promotionSavings.add(
                    linePromotionSavings
                );


            clubSavings =
                clubSavings.add(
                    lineClubSavings
                );


            total =
                total.add(
                    lineFinal
                );


            itemCount +=
                quantity;


            Map<String,Object> line =
                new LinkedHashMap<>();


            line.put(
                "sku",
                sku
            );

            line.put(
                "product",
                product.name()
            );

            line.put(
                "quantity",
                quantity
            );

            line.put(
                "baseUnitPrice",
                baseUnit
            );

            line.put(
                "promotionPct",
                money(
                    product.discountPct()
                )
            );

            line.put(
                "promotionUnitPrice",
                promotionUnit
            );

            line.put(
                "clubDiscountPct",
                money(
                    profile.clubDiscountPct()
                )
            );

            line.put(
                "finalUnitPrice",
                finalUnit
            );

            line.put(
                "lineTotal",
                lineFinal
            );


            lines.add(line);

        }


        subtotal =
            money(subtotal);

        promotionSavings =
            money(promotionSavings);

        clubSavings =
            money(clubSavings);

        total =
            money(total);


        BigDecimal totalSavings =
            money(
                promotionSavings.add(
                    clubSavings
                )
            );


        String orderId =
            nextOrderId();


        String createdAt =
            Instant.now().toString();


        Map<String,Object> order =
            new LinkedHashMap<>();


        order.put(
            "orderId",
            orderId
        );

        order.put(
            "createdAt",
            createdAt
        );

        order.put(
            "userId",
            profile.id()
        );

        order.put(
            "customer",
            profile.name()
        );

        order.put(
            "tier",
            profile.tier()
        );

        order.put(
            "itemCount",
            itemCount
        );

        order.put(
            "subtotal",
            subtotal
        );

        order.put(
            "promotionSavings",
            promotionSavings
        );

        order.put(
            "clubSavings",
            clubSavings
        );

        order.put(
            "totalSavings",
            totalSavings
        );

        order.put(
            "total",
            total
        );

        order.put(
            "version",
            version()
        );

        order.put(
            "items",
            lines
        );


        saveOrder(
            profile.id(),
            order
        );


        log.info(
            "event=checkout_success user={} tier={} order={} items={} subtotal={} promotion_savings={} club_savings={} total={} version={}",
            profile.id(),
            profile.tier(),
            orderId,
            itemCount,
            subtotal,
            promotionSavings,
            clubSavings,
            total,
            version()
        );


        Map<String,Object> response =
            new LinkedHashMap<>();


        response.put(
            "status",
            "SUCCESS"
        );

        response.put(
            "order",
            order
        );


        return ResponseEntity.ok(
            response
        );

    }


    private ResponseEntity<Map<String,Object>>
    businessError(
        HttpStatus status,
        String reason,
        String message
    ) {

        Map<String,Object> body =
            new LinkedHashMap<>();


        body.put(
            "status",
            "FAILED"
        );

        body.put(
            "reason",
            reason
        );

        body.put(
            "message",
            message
        );


        return ResponseEntity
            .status(status)
            .body(body);

    }


    // ============================================================
    // ORDER HISTORY
    // ============================================================

    @GetMapping("/api/orders/{userId}")
    public ResponseEntity<Map<String,Object>>
    orderHistory(
        @PathVariable String userId
    ) {

        String normalized =
            userId
                .trim()
                .toLowerCase(
                    Locale.ROOT
                );


        CustomerProfile profile =
            customerProfiles.get(
                normalized
            );


        if (profile == null) {

            return businessError(
                HttpStatus.NOT_FOUND,
                "CUSTOMER_NOT_FOUND",
                normalized
            );

        }


        Deque<Map<String,Object>> customerOrders =
            orders.getOrDefault(
                normalized,
                new ConcurrentLinkedDeque<>()
            );


        Map<String,Object> response =
            new LinkedHashMap<>();


        response.put(
            "status",
            "SUCCESS"
        );

        response.put(
            "userId",
            normalized
        );

        response.put(
            "customer",
            profile.name()
        );

        response.put(
            "tier",
            profile.tier()
        );

        response.put(
            "orders",
            new ArrayList<>(
                customerOrders
            )
        );


        return ResponseEntity.ok(
            response
        );

    }


    private void saveOrder(
        String userId,
        Map<String,Object> order
    ) {

        Deque<Map<String,Object>> customerOrders =
            orders.computeIfAbsent(
                userId,
                key ->
                    new ConcurrentLinkedDeque<>()
            );


        customerOrders.addFirst(
            order
        );


        while (
            customerOrders.size() > 20
        ) {

            customerOrders.pollLast();

        }

    }


    private String nextOrderId() {

        return "NV-" +
            ORDER_TS.format(
                Instant.now()
            ) +
            "-" +
            orderSequence.incrementAndGet();

    }


    // ============================================================
    // EXISTING BUSINESS OPERATION
    //
    // Preserved for backward compatibility with the current
    // Synthetic test and technical demo scripts.
    // ============================================================

    @GetMapping("/api/operation/{sku}")
    public ResponseEntity<Map<String,Object>>
    operation(
        @PathVariable String sku
    ) {

        long age =
            fileAgeSeconds();


        if (age > maxAgeSeconds) {

            log.error(
                "event=operation_rejected reason=stale_file age_seconds={} version={}",
                age,
                version()
            );


            return ResponseEntity
                .status(
                    HttpStatus.SERVICE_UNAVAILABLE
                )
                .body(
                    Map.of(
                        "status",
                        "FAILED",
                        "reason",
                        "PROMOTIONS_FILE_STALE",
                        "ageSeconds",
                        age,
                        "version",
                        version()
                    )
                );

        }


        Product product =
            products.get(sku);


        if (product == null) {

            return ResponseEntity
                .notFound()
                .build();

        }


        BigDecimal finalPrice =
            promotionPrice(
                product
            );


        log.info(
            "event=operation_success sku={} version={} final_price={}",
            sku,
            version(),
            finalPrice
        );


        Map<String,Object> response =
            new LinkedHashMap<>();


        response.put(
            "status",
            "SUCCESS"
        );

        response.put(
            "sku",
            sku
        );

        response.put(
            "product",
            product.name()
        );

        response.put(
            "basePrice",
            money(
                product.basePrice()
            )
        );

        response.put(
            "discountPct",
            money(
                product.discountPct()
            )
        );

        response.put(
            "finalPrice",
            finalPrice
        );

        response.put(
            "version",
            version()
        );


        return ResponseEntity.ok(
            response
        );

    }


    // ============================================================
    // PRICING HELPERS
    // ============================================================

    private BigDecimal promotionPrice(
        Product product
    ) {

        BigDecimal discount =
            product
                .basePrice()
                .multiply(
                    product.discountPct()
                )
                .divide(
                    BigDecimal.valueOf(100),
                    6,
                    RoundingMode.HALF_UP
                );


        return money(
            product
                .basePrice()
                .subtract(
                    discount
                )
        );

    }


    private BigDecimal money(
        BigDecimal value
    ) {

        return value.setScale(
            2,
            RoundingMode.HALF_UP
        );

    }


    // ============================================================
    // DATA CONTRACTS
    // ============================================================

    record Product(
        String sku,
        String name,
        BigDecimal basePrice,
        BigDecimal discountPct,
        String version
    ) {}


    record CustomerProfile(
        String id,
        String name,
        String tier,
        BigDecimal clubDiscountPct
    ) {}


    record CheckoutItemRequest(
        String sku,
        Integer quantity
    ) {}


    record CheckoutRequest(
        String userId,
        List<CheckoutItemRequest> items
    ) {}

}

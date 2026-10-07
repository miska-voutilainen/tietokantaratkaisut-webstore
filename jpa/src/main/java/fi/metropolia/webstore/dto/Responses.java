package fi.metropolia.webstore.dto;

import fi.metropolia.webstore.entity.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

// API:n vastaukset. Entiteettejä ei palauteta suoraan, jotta laiskat liitokset eivät vuoda JSONiin.
public final class Responses {

    private Responses() {
    }

    public record CustomerResponse(Integer id, String firstName, String lastName, String email, String phone) {
        public static CustomerResponse of(Customer c) {
            return new CustomerResponse(c.getId(), c.getFirstName(), c.getLastName(), c.getEmail(), c.getPhone());
        }
    }

    public record ProductResponse(Integer id, String name, String description, BigDecimal price, int stockQuantity,
                                  Integer categoryId, String categoryName, Integer supplierId, int version) {
        public static ProductResponse of(Product p) {
            ProductCategory category = p.getCategory();
            return new ProductResponse(p.getId(), p.getName(), p.getDescription(), p.getPrice(), p.getStockQuantity(),
                    category == null ? null : category.getId(), category == null ? null : category.getName(),
                    p.getSupplierId(), p.getVersion());
        }
    }

    public record OrderLineResponse(Integer productId, String productName, int quantity, BigDecimal unitPrice) {
        public static OrderLineResponse of(OrderItem item) {
            return new OrderLineResponse(item.getProduct().getId(), item.getProduct().getName(),
                    item.getQuantity(), item.getUnitPrice());
        }
    }

    public record OrderResponse(Integer id, Integer customerId, LocalDateTime orderDate, LocalDateTime deliveryDate,
                                String status, BigDecimal total, List<OrderLineResponse> items) {
        public static OrderResponse of(Order o) {
            List<OrderLineResponse> lines = o.getItems().stream().map(OrderLineResponse::of).toList();
            BigDecimal total = lines.stream()
                    .map(l -> l.unitPrice().multiply(BigDecimal.valueOf(l.quantity())))
                    .reduce(BigDecimal.ZERO, BigDecimal::add);
            return new OrderResponse(o.getId(), o.getCustomerId(), o.getOrderDate(), o.getDeliveryDate(),
                    o.getStatus().getCode(), total, lines);
        }

        public static OrderResponse withoutItems(Order o) {
            return new OrderResponse(o.getId(), o.getCustomerId(), o.getOrderDate(), o.getDeliveryDate(),
                    o.getStatus().getCode(), null, List.of());
        }
    }

    public record StatusHistoryResponse(String oldStatus, String newStatus, LocalDateTime changedAt, String changedBy) {
        public static StatusHistoryResponse of(OrderStatusHistory h) {
            return new StatusHistoryResponse(h.getOldStatus(), h.getNewStatus(), h.getChangedAt(), h.getChangedBy());
        }
    }

    public record PriceHistoryResponse(BigDecimal price, LocalDateTime validFrom, LocalDateTime validTo,
                                       String changeReason, String changedBy) {
        public static PriceHistoryResponse of(ProductPriceHistory h) {
            return new PriceHistoryResponse(h.getPrice(), h.getValidFrom(), h.getValidTo(),
                    h.getChangeReason(), h.getChangedBy());
        }
    }

    public record BulkResult(String operation, int affectedRows) {
    }
}

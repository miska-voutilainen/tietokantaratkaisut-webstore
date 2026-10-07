package fi.metropolia.webstore.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;

import java.math.BigDecimal;
import java.util.List;

// API:n pyyntörungot.
public final class Requests {

    private Requests() {
    }

    public record CustomerRequest(
            @NotBlank @Size(max = 100) String firstName,
            @NotBlank @Size(max = 100) String lastName,
            @NotBlank @Email @Size(max = 255) String email,
            @Size(max = 30) String phone) {
    }

    public record ProductCreateRequest(
            @NotBlank @Size(max = 255) String name,
            String description,
            @NotNull @DecimalMin(value = "0.01") @Digits(integer = 8, fraction = 2) BigDecimal price,
            @Min(0) int stockQuantity,
            Integer categoryId,
            Integer supplierId) {
    }

    public record ProductUpdateRequest(
            @NotBlank @Size(max = 255) String name,
            String description,
            @Min(0) int stockQuantity,
            Integer categoryId,
            Integer supplierId) {
    }

    public record PriceChangeRequest(
            @NotNull @DecimalMin(value = "0.01") @Digits(integer = 8, fraction = 2) BigDecimal price,
            @NotBlank @Size(max = 255) String reason) {
    }

    public record OrderLineRequest(@NotNull Integer productId, @Min(1) int quantity) {
    }

    public record OrderRequest(
            @NotNull Integer customerId,
            Integer shippingAddressId,
            @NotEmpty List<@Valid OrderLineRequest> items) {
    }

    public record StatusChangeRequest(@NotBlank String status) {
    }

    public record RestockRequest(Integer supplierId, @Min(1) int threshold, @Min(1) int amount) {
    }
}

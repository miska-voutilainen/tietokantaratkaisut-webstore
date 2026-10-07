package fi.metropolia.webstore.entity;

import jakarta.persistence.*;
import org.hibernate.annotations.Immutable;

import java.math.BigDecimal;
import java.time.LocalDateTime;

// Hinta on voimassa välillä [validFrom, validTo); validTo = null on nykyinen hinta.
// Tietokannan liipaisin kirjoittaa tämän taulun; sovellus vain lukee.
@Entity
@Immutable
@Table(name = "product_price_history")
public class ProductPriceHistory {

    @Id
    private Long id;

    @Column(name = "product_id")
    private Integer productId;

    @Column(name = "price")
    private BigDecimal price;

    @Column(name = "valid_from")
    private LocalDateTime validFrom;

    @Column(name = "valid_to")
    private LocalDateTime validTo;

    @Column(name = "change_reason")
    private String changeReason;

    @Column(name = "changed_by")
    private String changedBy;

    protected ProductPriceHistory() {
    }

    public Long getId() {
        return id;
    }

    public Integer getProductId() {
        return productId;
    }

    public BigDecimal getPrice() {
        return price;
    }

    public LocalDateTime getValidFrom() {
        return validFrom;
    }

    public LocalDateTime getValidTo() {
        return validTo;
    }

    public String getChangeReason() {
        return changeReason;
    }

    public String getChangedBy() {
        return changedBy;
    }
}

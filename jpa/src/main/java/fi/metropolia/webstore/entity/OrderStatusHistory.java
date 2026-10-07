package fi.metropolia.webstore.entity;

import jakarta.persistence.*;
import org.hibernate.annotations.Immutable;

import java.time.LocalDateTime;

// Tietokannan liipaisin kirjoittaa tämän taulun; sovellus vain lukee.
@Entity
@Immutable
@Table(name = "order_status_history")
public class OrderStatusHistory {

    @Id
    private Long id;

    @Column(name = "order_id")
    private Integer orderId;

    @Column(name = "old_status")
    private String oldStatus;

    @Column(name = "new_status")
    private String newStatus;

    @Column(name = "changed_at")
    private LocalDateTime changedAt;

    @Column(name = "changed_by")
    private String changedBy;

    protected OrderStatusHistory() {
    }

    public Long getId() {
        return id;
    }

    public Integer getOrderId() {
        return orderId;
    }

    public String getOldStatus() {
        return oldStatus;
    }

    public String getNewStatus() {
        return newStatus;
    }

    public LocalDateTime getChangedAt() {
        return changedAt;
    }

    public String getChangedBy() {
        return changedBy;
    }
}

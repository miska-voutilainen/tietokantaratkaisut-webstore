package fi.metropolia.webstore.entity;

import fi.metropolia.webstore.converter.OrderStatusConverter;
import jakarta.persistence.*;
import org.hibernate.annotations.DynamicUpdate;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

// Sovelluskäyttäjä saa päivittää vain tilaa, toimituspäivää ja toimitusosoitetta.
@Entity
@Table(name = "orders")
@DynamicUpdate
public class Order {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(name = "customer_id", nullable = false, updatable = false)
    private Integer customerId;

    @Column(name = "order_date", nullable = false, updatable = false)
    private LocalDateTime orderDate;

    @Column(name = "delivery_date")
    private LocalDateTime deliveryDate;

    @Column(name = "shipping_address_id")
    private Integer shippingAddressId;

    @Convert(converter = OrderStatusConverter.class)
    @Column(name = "status", length = 50)
    private OrderStatus status;

    @OneToMany(mappedBy = "order")
    private List<OrderItem> items = new ArrayList<>();

    protected Order() {
    }

    public Order(Integer customerId) {
        this.customerId = customerId;
    }

    // JPA lähettää INSERTissä myös null-arvot, joten tietokannan DEFAULT-arvot eivät toteudu.
    @PrePersist
    void beforeInsert() {
        if (orderDate == null) {
            orderDate = LocalDateTime.now();
        }
        if (status == null) {
            status = OrderStatus.UUSI;
        }
    }

    public Integer getId() {
        return id;
    }

    public Integer getCustomerId() {
        return customerId;
    }

    public LocalDateTime getOrderDate() {
        return orderDate;
    }

    public LocalDateTime getDeliveryDate() {
        return deliveryDate;
    }

    public void setDeliveryDate(LocalDateTime deliveryDate) {
        this.deliveryDate = deliveryDate;
    }

    public Integer getShippingAddressId() {
        return shippingAddressId;
    }

    public void setShippingAddressId(Integer shippingAddressId) {
        this.shippingAddressId = shippingAddressId;
    }

    public OrderStatus getStatus() {
        return status;
    }

    public void setStatus(OrderStatus status) {
        this.status = status;
    }

    public List<OrderItem> getItems() {
        return items;
    }
}

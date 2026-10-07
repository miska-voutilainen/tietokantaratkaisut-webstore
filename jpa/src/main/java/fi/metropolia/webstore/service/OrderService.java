package fi.metropolia.webstore.service;

import fi.metropolia.webstore.dto.Requests.OrderLineRequest;
import fi.metropolia.webstore.dto.Requests.OrderRequest;
import fi.metropolia.webstore.entity.*;
import fi.metropolia.webstore.repository.*;
import jakarta.persistence.EntityManager;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Service
public class OrderService {

    private final OrderRepository orders;
    private final OrderItemRepository orderItems;
    private final ProductRepository products;
    private final CustomerRepository customers;
    private final OrderStatusHistoryRepository statusHistory;
    private final EntityManager em;

    public OrderService(OrderRepository orders, OrderItemRepository orderItems, ProductRepository products,
                        CustomerRepository customers, OrderStatusHistoryRepository statusHistory, EntityManager em) {
        this.orders = orders;
        this.orderItems = orderItems;
        this.products = products;
        this.customers = customers;
        this.statusHistory = statusHistory;
        this.em = em;
    }

    // Koko tilaus on yksi transaktio: jos yhdenkin rivin saldo ei riitä, myös aiemmat rivit perutaan.
    @Transactional
    public Order create(OrderRequest r) {
        if (!customers.existsById(r.customerId())) {
            throw new NotFoundException("Asiakasta ei löydy: " + r.customerId());
        }
        Order order = new Order(r.customerId());
        order.setShippingAddressId(r.shippingAddressId());
        orders.saveAndFlush(order);

        for (OrderLineRequest line : r.items()) {
            Product product = products.findById(line.productId())
                    .orElseThrow(() -> new NotFoundException("Tuotetta ei löydy: " + line.productId()));
            if (products.decreaseStockIfAvailable(product.getId(), line.quantity()) == 0) {
                throw new ConflictException("Varastosaldo ei riitä tuotteelle " + product.getId());
            }
            orderItems.save(new OrderItem(order, product, line.quantity(), product.getPrice()));
        }
        orderItems.flush();
        em.clear();
        return get(order.getId());
    }

    @Transactional(readOnly = true)
    public Order get(Integer id) {
        return orders.findWithItems(id).orElseThrow(() -> new NotFoundException("Tilausta ei löydy: " + id));
    }

    @Transactional(readOnly = true)
    public List<Order> latestForCustomer(Integer customerId) {
        return orders.findTop20ByCustomerIdOrderByOrderDateDesc(customerId);
    }

    @Transactional
    public Order changeStatus(Integer id, OrderStatus status) {
        Order order = orders.findById(id).orElseThrow(() -> new NotFoundException("Tilausta ei löydy: " + id));
        if (order.getStatus() == OrderStatus.PERUTTU && status != OrderStatus.PERUTTU) {
            throw new ConflictException("Peruttua tilausta ei voi palauttaa");
        }
        order.setStatus(status);
        if (status == OrderStatus.TOIMITETTU && order.getDeliveryDate() == null) {
            order.setDeliveryDate(LocalDateTime.now());
        }
        orders.flush();
        return order;
    }

    @Transactional(readOnly = true)
    public List<OrderStatusHistory> statusHistory(Integer orderId) {
        return statusHistory.findByOrderIdOrderByIdAsc(orderId);
    }
}

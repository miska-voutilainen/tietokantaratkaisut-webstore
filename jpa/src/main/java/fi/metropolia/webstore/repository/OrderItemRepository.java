package fi.metropolia.webstore.repository;

import fi.metropolia.webstore.dto.CategorySales;
import fi.metropolia.webstore.entity.OrderItem;
import fi.metropolia.webstore.entity.OrderItemId;
import fi.metropolia.webstore.entity.OrderStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.List;

public interface OrderItemRepository extends JpaRepository<OrderItem, OrderItemId> {

    // Laaja raporttihaku: tietokanta suodattaa, liittää ja ryhmittelee satoja tuhansia tilausrivejä,
    // ja sovellukseen palautuu vain yksi rivi tuoteryhmää kohden.
    @Query("""
            SELECT new fi.metropolia.webstore.dto.CategorySales(
                       c.id, c.name,
                       COUNT(DISTINCT o.id),
                       SUM(oi.quantity),
                       SUM(oi.quantity * oi.unitPrice))
              FROM OrderItem oi
              JOIN oi.order o
              JOIN oi.product p
              JOIN p.category c
             WHERE o.orderDate >= :from
               AND o.orderDate < :to
               AND o.status <> :excludedStatus
             GROUP BY c.id, c.name
             ORDER BY SUM(oi.quantity * oi.unitPrice) DESC
            """)
    List<CategorySales> salesByCategory(@Param("from") LocalDateTime from,
                                        @Param("to") LocalDateTime to,
                                        @Param("excludedStatus") OrderStatus excludedStatus);
}

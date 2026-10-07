package fi.metropolia.webstore.repository;

import fi.metropolia.webstore.entity.Order;
import fi.metropolia.webstore.entity.OrderStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface OrderRepository extends JpaRepository<Order, Integer> {

    @Query("""
            SELECT DISTINCT o FROM Order o
              LEFT JOIN FETCH o.items i
              LEFT JOIN FETCH i.product
             WHERE o.id = :id
            """)
    Optional<Order> findWithItems(@Param("id") Integer id);

    List<Order> findTop20ByCustomerIdOrderByOrderDateDesc(Integer customerId);

    // Massaoperaatio: kaikki annettua hetkeä vanhemmat käsittelemättömät tilaukset perutaan yhdellä
    // UPDATE-lauseella. Tilan arvot kulkevat OrderStatusConverterin kautta ('NEW' -> 'CANCELLED').
    // clearAutomatically tyhjentää persistence contextin, koska siellä olevat Order-oliot ovat nyt vanhoja.
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("""
            UPDATE Order o
               SET o.status = :newStatus
             WHERE o.status = :currentStatus
               AND o.orderDate < :cutoff
            """)
    int bulkChangeStatus(@Param("currentStatus") OrderStatus currentStatus,
                         @Param("newStatus") OrderStatus newStatus,
                         @Param("cutoff") LocalDateTime cutoff);

    @Query("SELECT COUNT(o) FROM Order o WHERE o.status = :status AND o.orderDate < :cutoff")
    long countByStatusBefore(@Param("status") OrderStatus status, @Param("cutoff") LocalDateTime cutoff);
}

package fi.metropolia.webstore;

import fi.metropolia.webstore.entity.Order;
import fi.metropolia.webstore.entity.Product;
import jakarta.persistence.EntityManager;
import jakarta.persistence.EntityManagerFactory;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import java.math.BigDecimal;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
class LifecycleEventTest {

    @Autowired
    private EntityManagerFactory emf;

    @Test
    void prePersistFillsOrderDateAndStatus() {
        Order order = new Order(1);
        System.out.println("[PREPERSIST] ennen persist: orderDate=" + order.getOrderDate() + ", status=" + order.getStatus());
        TestDatabase.inTransaction(emf, em -> em.persist(order));

        EntityManager em = emf.createEntityManager();
        Object[] row = (Object[]) em.createNativeQuery("SELECT order_date, status FROM orders WHERE id = ?1")
                .setParameter(1, order.getId())
                .getSingleResult();
        em.close();

        System.out.println("[PREPERSIST] tietokannassa: order_date=" + row[0] + ", status=" + row[1]);
        assertNotNull(row[0]);
        assertEquals("NEW", row[1]);
    }

    @Test
    void preUpdateRejectsNegativeStock() {
        Product product = new Product("Testituote", new BigDecimal("19.90"), 3);
        TestDatabase.inTransaction(emf, em -> em.persist(product));

        RuntimeException error = assertThrows(RuntimeException.class, () ->
                TestDatabase.inTransaction(emf, em -> em.find(Product.class, product.getId()).decreaseStock(5)));

        EntityManager em = emf.createEntityManager();
        int stockAfter = em.find(Product.class, product.getId()).getStockQuantity();
        em.close();

        System.out.println("[PREUPDATE] saldo 3, yritetään vähentää 5 -> " + rootCause(error).getMessage());
        System.out.println("[PREUPDATE] saldo tietokannassa yrityksen jälkeen: " + stockAfter);
        assertEquals(3, stockAfter);
    }

    private static Throwable rootCause(Throwable error) {
        while (error.getCause() != null) {
            error = error.getCause();
        }
        return error;
    }
}

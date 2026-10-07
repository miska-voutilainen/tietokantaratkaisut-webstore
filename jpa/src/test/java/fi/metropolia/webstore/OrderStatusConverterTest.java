package fi.metropolia.webstore;

import fi.metropolia.webstore.entity.Order;
import fi.metropolia.webstore.entity.OrderStatus;
import jakarta.persistence.EntityManager;
import jakarta.persistence.EntityManagerFactory;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import static org.junit.jupiter.api.Assertions.assertEquals;

@SpringBootTest
class OrderStatusConverterTest {

    @Autowired
    private EntityManagerFactory emf;

    @Test
    void statusIsStoredAsCodeAndReadBackAsEnum() {
        Order order = new Order(1);
        order.setStatus(OrderStatus.TOIMITETTU);
        TestDatabase.inTransaction(emf, em -> em.persist(order));

        EntityManager em = emf.createEntityManager();
        String rawStatus = (String) em.createNativeQuery("SELECT status FROM orders WHERE id = ?1")
                .setParameter(1, order.getId())
                .getSingleResult();
        OrderStatus loaded = em.find(Order.class, order.getId()).getStatus();
        em.close();

        System.out.println("[CONVERTER] Java ennen tallennusta: " + OrderStatus.TOIMITETTU);
        System.out.println("[CONVERTER] orders.status tietokannassa: " + rawStatus);
        System.out.println("[CONVERTER] Java uudelleenluvun jälkeen: " + loaded);
        assertEquals("SHIPPED", rawStatus);
        assertEquals(OrderStatus.TOIMITETTU, loaded);
    }

    @Test
    void existingDatabaseCodeIsReadAsEnum() {
        TestDatabase.inTransaction(emf, em -> em.createNativeQuery(
                "INSERT INTO orders (id, customer_id, order_date, status) VALUES (900, 1, NOW(), 'CANCELLED')")
                .executeUpdate());

        EntityManager em = emf.createEntityManager();
        OrderStatus loaded = em.find(Order.class, 900).getStatus();
        em.close();

        System.out.println("[CONVERTER] SQL:llä lisätty 'CANCELLED' luetaan Javaan: " + loaded);
        assertEquals(OrderStatus.PERUTTU, loaded);
    }
}

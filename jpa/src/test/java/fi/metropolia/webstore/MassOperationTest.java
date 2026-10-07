package fi.metropolia.webstore;

import fi.metropolia.webstore.dto.CategorySales;
import fi.metropolia.webstore.entity.Product;
import fi.metropolia.webstore.service.MassOperationService;
import jakarta.persistence.EntityManager;
import jakarta.persistence.EntityManagerFactory;
import jakarta.persistence.OptimisticLockException;
import jakarta.persistence.RollbackException;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.jdbc.Sql;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

// Todennus SELECTillä ennen ja jälkeen: JdbcTemplate lukee tietokantaa JPA:n ohi.
@SpringBootTest
@Sql("/mass-operation-data.sql")
class MassOperationTest {

    @Autowired
    private MassOperationService massOperations;

    @Autowired
    private JdbcTemplate jdbc;

    @Autowired
    private EntityManagerFactory emf;

    @Test
    void jpqlUpdateCancelsOnlyStaleNewOrders() {
        LocalDateTime cutoff = LocalDateTime.of(2025, 1, 1, 0, 0);
        printStatuses("ennen");

        int updated = massOperations.cancelStaleOrders(cutoff);

        printStatuses("jälkeen");
        assertEquals(3, updated);
        assertEquals("CANCELLED", status(1001));
        assertEquals("CANCELLED", status(1002));
        assertEquals("CANCELLED", status(1003));
        assertEquals("NEW", status(1004), "tuore tilaus ei kuulu rajaukseen");
        assertEquals("SHIPPED", status(1005), "toimitettu tilaus ei kuulu rajaukseen");
    }

    @Test
    void jpqlUpdateIsIdempotent() {
        LocalDateTime cutoff = LocalDateTime.of(2025, 1, 1, 0, 0);
        assertEquals(3, massOperations.cancelStaleOrders(cutoff));
        assertEquals(0, massOperations.cancelStaleOrders(cutoff), "toinen ajo ei löydä enää muutettavaa");
    }

    @Test
    void criteriaUpdateRestocksLowStockOfOneSupplier() {
        printStock("ennen");

        int updated = massOperations.restockLowStock(7, 10, 20);

        printStock("jälkeen");
        assertEquals(2, updated);
        assertEquals(22, stock(101));
        assertEquals(25, stock(102));
        assertEquals(50, stock(103), "saldo ylittää rajan");
        assertEquals(1, stock(104), "eri toimittaja");
        assertEquals(1, version(101), "massapäivitys kasvattaa versiota");
        assertEquals(0, version(103));
    }

    @Test
    void criteriaUpdateWithoutSupplierRestocksAllLowStock() {
        assertEquals(4, massOperations.restockLowStock(null, 10, 5));
        assertEquals(5, stock(105));
        assertEquals(30, stock(106));
    }

    // Massapäivitys ohittaa entiteetit. Ilman version kasvatusta ennen päivitystä luettu entiteetti
    // kirjoittaisi vanhan saldon takaisin; nyt optimistinen lukitus torjuu sen.
    @Test
    void entityReadBeforeBulkUpdateCannotOverwriteIt() {
        EntityManager userA = emf.createEntityManager();
        userA.getTransaction().begin();
        Product stale = userA.find(Product.class, 101);

        massOperations.restockLowStock(7, 10, 20);

        stale.decreaseStock(1);
        RollbackException error = assertThrows(RollbackException.class, () -> userA.getTransaction().commit());
        userA.close();
        System.out.println("[MASSA] vanhan entiteetin tallennus massapäivityksen jälkeen -> "
                + error.getCause().getClass().getSimpleName());
        assertInstanceOf(OptimisticLockException.class, error.getCause());
        assertEquals(22, stock(101));
    }

    @Test
    void jpqlReportGroupsSalesByCategory() {
        List<CategorySales> rows = massOperations.salesByCategory(
                LocalDateTime.of(2024, 1, 1, 0, 0), LocalDateTime.of(2025, 1, 1, 0, 0));
        rows.forEach(r -> System.out.println("[MASSA] raporttirivi: " + r));

        // Tilaus 1006 on peruttu ja 1004 aikavälin ulkopuolella.
        assertEquals(2, rows.size());
        CategorySales electronics = rows.get(0);
        assertEquals("Elektroniikka", electronics.categoryName());
        assertEquals(3, electronics.orderCount());
        assertEquals(9, electronics.itemCount());
        assertEquals(new BigDecimal("219.10"), electronics.revenue());

        CategorySales clothes = rows.get(1);
        assertEquals("Vaatteet", clothes.categoryName());
        assertEquals(2, clothes.orderCount());
        assertEquals(2, clothes.itemCount());
        assertEquals(new BigDecimal("143.90"), clothes.revenue());
    }

    private void printStatuses(String phase) {
        List<Map<String, Object>> rows = jdbc.queryForList("SELECT id, order_date, status FROM orders ORDER BY id");
        System.out.println("[MASSA] tilaukset " + phase + ": " + rows);
    }

    private void printStock(String phase) {
        List<Map<String, Object>> rows = jdbc.queryForList(
                "SELECT id, supplier_id, stock_quantity, version FROM products ORDER BY id");
        System.out.println("[MASSA] saldot " + phase + ": " + rows);
    }

    private String status(int orderId) {
        return jdbc.queryForObject("SELECT status FROM orders WHERE id = ?", String.class, orderId);
    }

    private int stock(int productId) {
        return jdbc.queryForObject("SELECT stock_quantity FROM products WHERE id = ?", Integer.class, productId);
    }

    private int version(int productId) {
        return jdbc.queryForObject("SELECT version FROM products WHERE id = ?", Integer.class, productId);
    }
}

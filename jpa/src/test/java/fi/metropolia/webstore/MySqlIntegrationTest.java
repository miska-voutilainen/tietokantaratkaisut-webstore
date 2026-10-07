package fi.metropolia.webstore;

import fi.metropolia.webstore.dto.CategorySales;
import fi.metropolia.webstore.dto.Requests.OrderLineRequest;
import fi.metropolia.webstore.dto.Requests.OrderRequest;
import fi.metropolia.webstore.dto.Requests.PriceChangeRequest;
import fi.metropolia.webstore.entity.Order;
import fi.metropolia.webstore.entity.OrderStatus;
import fi.metropolia.webstore.entity.Product;
import fi.metropolia.webstore.service.ConflictException;
import fi.metropolia.webstore.service.MassOperationService;
import fi.metropolia.webstore.service.OrderService;
import fi.metropolia.webstore.service.ProductService;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.support.TransactionTemplate;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.List;
import java.util.concurrent.*;

import static org.junit.jupiter.api.Assertions.*;

// Ajetaan koko asennettua MySQL-kantaa vasten sovelluskäyttäjänä (webstore_app), jolloin myös
// liipaisimet, proseduurit ja käyttöoikeudet ovat mukana. Muuttaa dataa: aja testikannassa.
//   set WEBSTORE_MYSQL_URL=jdbc:mysql://127.0.0.1:3306/webstore
//   set WEBSTORE_MYSQL_PASSWORD=App_vaihda_2026!
//   mvn test -Dtest=MySqlIntegrationTest
@EnabledIfEnvironmentVariable(named = "WEBSTORE_MYSQL_URL", matches = ".+")
@SpringBootTest(properties = {
        "spring.datasource.url=${WEBSTORE_MYSQL_URL}",
        "spring.datasource.username=${WEBSTORE_MYSQL_USER:webstore_app}",
        "spring.datasource.password=${WEBSTORE_MYSQL_PASSWORD}",
        "spring.sql.init.mode=never"
})
class MySqlIntegrationTest {

    @Autowired
    private MassOperationService massOperations;

    @Autowired
    private ProductService products;

    @Autowired
    private OrderService orders;

    @Autowired
    private JdbcTemplate jdbc;

    @Autowired
    private TransactionTemplate transactions;

    @PersistenceContext
    private EntityManager em;

    // Massapäivitys + rivikohtainen liipaisin: jokainen peruttu tilaus saa oman lokirivin.
    @Test
    void jpqlBulkCancelFiresStatusTriggerForEveryRow() {
        LocalDateTime cutoff = LocalDateTime.of(2024, 1, 1, 0, 0);
        int staleBefore = count("SELECT COUNT(*) FROM orders WHERE status = 'NEW' AND order_date < ?", cutoff);
        int logBefore = count("SELECT COUNT(*) FROM order_status_history WHERE new_status = 'CANCELLED'");

        long start = System.nanoTime();
        int updated = massOperations.cancelStaleOrders(cutoff);
        long millis = (System.nanoTime() - start) / 1_000_000;

        int staleAfter = count("SELECT COUNT(*) FROM orders WHERE status = 'NEW' AND order_date < ?", cutoff);
        int logAfter = count("SELECT COUNT(*) FROM order_status_history WHERE new_status = 'CANCELLED'");
        System.out.printf("[MYSQL] JPQL UPDATE: ennen %d, päivitetty %d, jälkeen %d, lokirivejä +%d, %d ms%n",
                staleBefore, updated, staleAfter, logAfter - logBefore, millis);

        assertEquals(staleBefore, updated);
        assertEquals(0, staleAfter);
        assertEquals(updated, logAfter - logBefore);
    }

    // Vertailu: sama muutos entiteettisilmukalla (haku + muutos jokaiselle) ja yhdellä JPQL UPDATElla
    // kahdelle samankokoiselle kuukaudelle. Molemmat perutaan lopuksi, joten testi on toistettava.
    @Test
    void loopVersusBulkUpdate() {
        LocalDateTime jan = LocalDateTime.of(2025, 1, 1, 0, 0);
        LocalDateTime feb = LocalDateTime.of(2025, 2, 1, 0, 0);
        LocalDateTime mar = LocalDateTime.of(2025, 3, 1, 0, 0);

        long loopStart = System.nanoTime();
        int looped = transactions.execute(tx -> {
            List<Order> stale = em.createQuery(
                            "SELECT o FROM Order o WHERE o.status = :s AND o.orderDate >= :from AND o.orderDate < :to", Order.class)
                    .setParameter("s", OrderStatus.UUSI).setParameter("from", jan).setParameter("to", feb)
                    .getResultList();
            stale.forEach(o -> o.setStatus(OrderStatus.PERUTTU));
            em.flush();
            tx.setRollbackOnly();
            return stale.size();
        });
        long loopMillis = (System.nanoTime() - loopStart) / 1_000_000;

        long bulkStart = System.nanoTime();
        int bulk = transactions.execute(tx -> {
            int updated = em.createQuery(
                            "UPDATE Order o SET o.status = :n WHERE o.status = :s AND o.orderDate >= :from AND o.orderDate < :to")
                    .setParameter("n", OrderStatus.PERUTTU).setParameter("s", OrderStatus.UUSI)
                    .setParameter("from", feb).setParameter("to", mar)
                    .executeUpdate();
            tx.setRollbackOnly();
            return updated;
        });
        long bulkMillis = (System.nanoTime() - bulkStart) / 1_000_000;

        System.out.printf("[MYSQL] silmukka: %d tilausta, 1 SELECT + %d UPDATE, %d ms%n", looped, looped, loopMillis);
        System.out.printf("[MYSQL] massa-UPDATE: %d tilausta, 1 UPDATE, %d ms%n", bulk, bulkMillis);
        assertTrue(looped > 0 && bulk > 0);
    }

    @Test
    void criteriaRestockUpdatesEveryLowStockProduct() {
        int lowBefore = count("SELECT COUNT(*) FROM products WHERE stock_quantity < 10");

        int updated = massOperations.restockLowStock(null, 10, 50);

        int lowAfter = count("SELECT COUNT(*) FROM products WHERE stock_quantity < 10");
        System.out.printf("[MYSQL] CriteriaUpdate: alle 10 kpl ennen %d, päivitetty %d, jälkeen %d%n",
                lowBefore, updated, lowAfter);
        assertEquals(lowBefore, updated);
        assertEquals(0, lowAfter);
    }

    @Test
    void jpqlReportMatchesPlainSql() {
        LocalDateTime from = LocalDateTime.of(2025, 1, 1, 0, 0);
        LocalDateTime to = LocalDateTime.of(2025, 7, 1, 0, 0);

        long start = System.nanoTime();
        List<CategorySales> rows = massOperations.salesByCategory(from, to);
        long millis = (System.nanoTime() - start) / 1_000_000;
        rows.forEach(r -> System.out.println("[MYSQL] " + r));
        System.out.println("[MYSQL] raportti " + rows.size() + " riviä, " + millis + " ms");

        BigDecimal expected = jdbc.queryForObject("""
                SELECT SUM(oi.quantity * oi.unit_price)
                FROM orderitems oi JOIN orders o ON o.id = oi.order_id
                JOIN products p ON p.id = oi.product_id
                WHERE o.order_date >= ? AND o.order_date < ? AND o.status <> 'CANCELLED'
                  AND p.category_id IS NOT NULL
                """, BigDecimal.class, from, to);
        BigDecimal total = rows.stream().map(CategorySales::revenue).reduce(BigDecimal.ZERO, BigDecimal::add);
        assertEquals(0, expected.compareTo(total));
    }

    // Hinta ei muutu JPA:lla (updatable = false) eikä suoralla SQL:llä (ei UPDATE-oikeutta price-sarakkeeseen),
    // vaan proseduurilla, joka kirjaa hintahistorian.
    @Test
    void priceChangesOnlyThroughProcedureAndIsRecordedInHistory() {
        int productId = 10;
        Product before = products.get(productId);
        BigDecimal newPrice = before.getPrice().multiply(new BigDecimal("1.05")).setScale(2, RoundingMode.HALF_UP);

        DataAccessException denied = assertThrows(DataAccessException.class,
                () -> jdbc.update("UPDATE products SET price = 1 WHERE id = ?", productId));
        System.out.println("[MYSQL] suora hinnan UPDATE -> " + denied.getMostSpecificCause().getMessage());

        Product after = products.changePrice(productId, new PriceChangeRequest(newPrice, "integraatiotesti +5 %"));
        System.out.println("[MYSQL] hinta " + before.getPrice() + " -> " + after.getPrice()
                + ", versio " + before.getVersion() + " -> " + after.getVersion());

        assertEquals(0, newPrice.compareTo(after.getPrice()));
        assertEquals(before.getVersion() + 1, after.getVersion());
        var current = products.priceAt(productId, LocalDateTime.now().plusSeconds(1));
        assertEquals(0, newPrice.compareTo(current.getPrice()));
        assertEquals("integraatiotesti +5 %", current.getChangeReason());
        assertTrue(current.getChangedBy().startsWith("webstore_app@"));
    }

    // Kaksi samanaikaista tilausta viimeisistä kappaleista: atominen UPDATE ja automaattinen
    // rivilukko päästävät läpi vain toisen.
    @Test
    void concurrentOrdersCannotOversell() throws Exception {
        int productId = 899;
        jdbc.update("UPDATE products SET stock_quantity = 3 WHERE id = ?", productId);

        ExecutorService pool = Executors.newFixedThreadPool(2);
        CountDownLatch start = new CountDownLatch(1);
        Callable<String> buyTwo = () -> {
            start.await();
            try {
                return "OK, tilaus " + orders.create(new OrderRequest(4242, null,
                        List.of(new OrderLineRequest(productId, 2)))).getId();
            } catch (ConflictException e) {
                return "TORJUTTU: " + e.getMessage();
            }
        };
        Future<String> a = pool.submit(buyTwo);
        Future<String> b = pool.submit(buyTwo);
        start.countDown();
        List<String> results = List.of(a.get(30, TimeUnit.SECONDS), b.get(30, TimeUnit.SECONDS));
        pool.shutdown();

        int stockAfter = count("SELECT stock_quantity FROM products WHERE id = ?", productId);
        System.out.println("[MYSQL] samanaikaiset tilaukset: " + results + ", saldo lopuksi " + stockAfter);
        assertEquals(1, results.stream().filter(r -> r.startsWith("OK")).count());
        assertEquals(1, stockAfter);
    }

    private int count(String sql, Object... args) {
        return jdbc.queryForObject(sql, Integer.class, args);
    }
}

package fi.metropolia.webstore;

import fi.metropolia.webstore.entity.Product;
import jakarta.persistence.EntityManager;
import jakarta.persistence.EntityManagerFactory;
import jakarta.persistence.OptimisticLockException;
import jakarta.persistence.RollbackException;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import java.math.BigDecimal;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
class OptimisticLockingTest {

    @Autowired
    private EntityManagerFactory emf;

    @Test
    void secondConcurrentUpdateIsRejected() {
        Product product = new Product("Kuulokkeet", new BigDecimal("59.90"), 136);
        TestDatabase.inTransaction(emf, em -> em.persist(product));
        int id = product.getId();

        // Kaksi käyttäjää lukee saman tuotteen samaan aikaan.
        EntityManager userA = emf.createEntityManager();
        EntityManager userB = emf.createEntityManager();
        userA.getTransaction().begin();
        userB.getTransaction().begin();
        Product seenByA = userA.find(Product.class, id);
        Product seenByB = userB.find(Product.class, id);
        System.out.println("[VERSION] A ja B lukevat: saldo=" + seenByA.getStockQuantity() + ", version=" + seenByA.getVersion());

        seenByA.decreaseStock(2);
        userA.getTransaction().commit();
        System.out.println("[VERSION] A tilaa 2 kpl ja tallentaa: saldo=" + seenByA.getStockQuantity() + ", version=" + seenByA.getVersion());

        seenByB.decreaseStock(5);
        RollbackException error = assertThrows(RollbackException.class, () -> userB.getTransaction().commit());
        System.out.println("[VERSION] B tilaa 5 kpl vanhan saldon perusteella -> " + error.getCause().getClass().getSimpleName());
        assertInstanceOf(OptimisticLockException.class, error.getCause());
        userA.close();
        userB.close();

        EntityManager check = emf.createEntityManager();
        Product afterConflict = check.find(Product.class, id);
        System.out.println("[VERSION] tietokannassa konfliktin jälkeen: saldo=" + afterConflict.getStockQuantity() + ", version=" + afterConflict.getVersion());
        assertEquals(134, afterConflict.getStockQuantity());
        assertEquals(1, afterConflict.getVersion());
        check.close();

        // B lukee tuoreen tiedon ja yrittää uudelleen.
        TestDatabase.inTransaction(emf, em -> em.find(Product.class, id).decreaseStock(5));
        EntityManager retry = emf.createEntityManager();
        Product afterRetry = retry.find(Product.class, id);
        System.out.println("[VERSION] B:n uusintayritys: saldo=" + afterRetry.getStockQuantity() + ", version=" + afterRetry.getVersion());
        assertEquals(129, afterRetry.getStockQuantity());
        assertEquals(2, afterRetry.getVersion());
        retry.close();
    }
}

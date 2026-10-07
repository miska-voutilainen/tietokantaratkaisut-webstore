package fi.metropolia.webstore;

import jakarta.persistence.EntityManager;
import jakarta.persistence.EntityManagerFactory;

import java.util.function.Consumer;

final class TestDatabase {

    private TestDatabase() {
    }

    // Oma EntityManager ja transaktio, joka vahvistetaan heti: testi näkee saman tilan kuin
    // tietokanta näkisi kahden erillisen käyttäjän välillä.
    static void inTransaction(EntityManagerFactory emf, Consumer<EntityManager> work) {
        EntityManager em = emf.createEntityManager();
        try {
            em.getTransaction().begin();
            work.accept(em);
            em.getTransaction().commit();
        } finally {
            if (em.getTransaction().isActive()) {
                em.getTransaction().rollback();
            }
            em.close();
        }
    }
}

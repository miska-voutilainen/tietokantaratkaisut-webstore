package fi.metropolia.webstore.repository;

import fi.metropolia.webstore.entity.Product;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.jpa.repository.query.Procedure;
import org.springframework.data.repository.query.Param;

import java.math.BigDecimal;

public interface ProductRepository extends JpaRepository<Product, Integer>, ProductRepositoryCustom {

    // Tarkistus ja vähennys samassa lauseessa: automaattinen rivilukko riittää, eikä kahta
    // samanaikaista tilausta voi hyväksyä samasta viimeisestä kappaleesta. 0 = saldo ei riittänyt.
    @Modifying(flushAutomatically = true)
    @Query("""
            UPDATE Product p
               SET p.stockQuantity = p.stockQuantity - :quantity,
                   p.version = p.version + 1
             WHERE p.id = :id
               AND p.stockQuantity >= :quantity
            """)
    int decreaseStockIfAvailable(@Param("id") Integer id, @Param("quantity") int quantity);

    // Hinta muuttuu vain tietokannan proseduurilla (sovelluskäyttäjällä ei ole UPDATE-oikeutta price-sarakkeeseen).
    @Procedure(procedureName = "change_product_price")
    void changeProductPrice(Integer productId, BigDecimal newPrice, String reason);
}

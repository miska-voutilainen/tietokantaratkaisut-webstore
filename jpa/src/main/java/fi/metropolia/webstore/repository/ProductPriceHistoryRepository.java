package fi.metropolia.webstore.repository;

import fi.metropolia.webstore.entity.ProductPriceHistory;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface ProductPriceHistoryRepository extends JpaRepository<ProductPriceHistory, Long> {

    List<ProductPriceHistory> findByProductIdOrderByValidFromAsc(Integer productId);

    // Temporaalinen haku: hinta, joka oli voimassa annettuna hetkenä.
    @Query("""
            SELECT h FROM ProductPriceHistory h
             WHERE h.productId = :productId
               AND h.validFrom <= :at
               AND (h.validTo IS NULL OR h.validTo > :at)
            """)
    Optional<ProductPriceHistory> findPriceAt(@Param("productId") Integer productId, @Param("at") LocalDateTime at);
}

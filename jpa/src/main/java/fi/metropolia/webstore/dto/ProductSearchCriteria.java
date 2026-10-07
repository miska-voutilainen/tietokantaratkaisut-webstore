package fi.metropolia.webstore.dto;

import java.math.BigDecimal;

// Kaikki ehdot ovat valinnaisia; null tarkoittaa, ettei ehtoa käytetä.
public record ProductSearchCriteria(String name, Integer categoryId, Integer supplierId,
                                    BigDecimal minPrice, BigDecimal maxPrice, Boolean inStock, Integer limit) {

    public static final int DEFAULT_LIMIT = 50;
    public static final int MAX_LIMIT = 200;

    public int effectiveLimit() {
        if (limit == null || limit <= 0) {
            return DEFAULT_LIMIT;
        }
        return Math.min(limit, MAX_LIMIT);
    }
}

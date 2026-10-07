package fi.metropolia.webstore.dto;

import java.math.BigDecimal;

// JPQL:n konstruktorilauseke (SELECT new ...) täyttää tämän suoraan ryhmittelyn tuloksesta.
public record CategorySales(Integer categoryId, String categoryName, Long orderCount, Long itemCount, BigDecimal revenue) {
}

package fi.metropolia.webstore;

import fi.metropolia.webstore.dto.ProductSearchCriteria;
import fi.metropolia.webstore.entity.Product;
import fi.metropolia.webstore.service.ProductService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.jdbc.Sql;

import java.math.BigDecimal;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;

@SpringBootTest
@Sql("/mass-operation-data.sql")
class ProductSearchTest {

    @Autowired
    private ProductService products;

    @Test
    void withoutConditionsReturnsAllByPrice() {
        assertEquals(List.of(103, 104, 102, 101, 105, 106), ids(criteria(null, null, null, null, null, null)));
    }

    @Test
    void combinesCategoryPriceRangeAndStock() {
        List<Integer> found = ids(criteria(null, 1, null, new BigDecimal("10.00"), new BigDecimal("100.00"), true));
        assertEquals(List.of(102, 101), found);
    }

    @Test
    void nameSearchIsCaseInsensitive() {
        assertEquals(List.of(101), ids(criteria("KUULO", null, null, null, null, null)));
    }

    @Test
    void inStockExcludesSoldOut() {
        assertEquals(List.of(104), ids(criteria(null, null, 8, null, null, true)));
    }

    @Test
    void limitIsApplied() {
        assertEquals(2, products.search(new ProductSearchCriteria(null, null, null, null, null, null, 2)).size());
    }

    private static ProductSearchCriteria criteria(String name, Integer categoryId, Integer supplierId,
                                                  BigDecimal min, BigDecimal max, Boolean inStock) {
        return new ProductSearchCriteria(name, categoryId, supplierId, min, max, inStock, null);
    }

    private List<Integer> ids(ProductSearchCriteria criteria) {
        List<Integer> ids = products.search(criteria).stream().map(Product::getId).toList();
        System.out.println("[CRITERIA] " + criteria + " -> " + ids);
        return ids;
    }
}

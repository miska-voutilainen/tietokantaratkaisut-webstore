package fi.metropolia.webstore.repository;

import fi.metropolia.webstore.dto.ProductSearchCriteria;
import fi.metropolia.webstore.entity.Product;

import java.util.List;

// Criteria API -toteutukset: ProductRepositoryImpl.
public interface ProductRepositoryCustom {

    List<Product> search(ProductSearchCriteria criteria);

    int restockLowStock(Integer supplierId, int threshold, int amount);
}

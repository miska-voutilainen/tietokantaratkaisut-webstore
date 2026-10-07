package fi.metropolia.webstore.service;

import fi.metropolia.webstore.dto.ProductSearchCriteria;
import fi.metropolia.webstore.dto.Requests.PriceChangeRequest;
import fi.metropolia.webstore.dto.Requests.ProductCreateRequest;
import fi.metropolia.webstore.dto.Requests.ProductUpdateRequest;
import fi.metropolia.webstore.entity.Product;
import fi.metropolia.webstore.entity.ProductCategory;
import fi.metropolia.webstore.entity.ProductPriceHistory;
import fi.metropolia.webstore.repository.ProductCategoryRepository;
import fi.metropolia.webstore.repository.ProductPriceHistoryRepository;
import fi.metropolia.webstore.repository.ProductRepository;
import jakarta.persistence.EntityManager;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Service
public class ProductService {

    private final ProductRepository products;
    private final ProductCategoryRepository categories;
    private final ProductPriceHistoryRepository priceHistory;
    private final EntityManager em;

    public ProductService(ProductRepository products, ProductCategoryRepository categories,
                          ProductPriceHistoryRepository priceHistory, EntityManager em) {
        this.products = products;
        this.categories = categories;
        this.priceHistory = priceHistory;
        this.em = em;
    }

    @Transactional(readOnly = true)
    public List<Product> search(ProductSearchCriteria criteria) {
        return products.search(criteria);
    }

    @Transactional(readOnly = true)
    public Product get(Integer id) {
        Product product = products.findById(id).orElseThrow(() -> new NotFoundException("Tuotetta ei löydy: " + id));
        if (product.getCategory() != null) {
            product.getCategory().getName();
        }
        return product;
    }

    @Transactional
    public Product create(ProductCreateRequest r) {
        Product product = new Product(r.name(), r.description(), r.price(), r.stockQuantity(),
                category(r.categoryId()), r.supplierId());
        return products.saveAndFlush(product);
    }

    @Transactional
    public Product update(Integer id, ProductUpdateRequest r) {
        Product product = get(id);
        product.update(r.name(), r.description(), r.stockQuantity(), category(r.categoryId()), r.supplierId());
        products.flush();
        return product;
    }

    @Transactional
    public void delete(Integer id) {
        products.delete(get(id));
        products.flush();
    }

    // Proseduuri avaa ja vahvistaa oman transaktionsa, joten hinnanmuutos ajetaan omana operaationaan.
    // Lopuksi entiteetti luetaan uudelleen, koska välimuistissa oleva hinta ja versio ovat vanhoja.
    @Transactional
    public Product changePrice(Integer id, PriceChangeRequest r) {
        get(id);
        products.changeProductPrice(id, r.price(), r.reason());
        em.clear();
        return get(id);
    }

    @Transactional(readOnly = true)
    public List<ProductPriceHistory> priceHistory(Integer productId) {
        get(productId);
        return priceHistory.findByProductIdOrderByValidFromAsc(productId);
    }

    @Transactional(readOnly = true)
    public ProductPriceHistory priceAt(Integer productId, LocalDateTime at) {
        return priceHistory.findPriceAt(productId, at)
                .orElseThrow(() -> new NotFoundException("Tuotteelle " + productId + " ei ole hintaa hetkellä " + at));
    }

    private ProductCategory category(Integer categoryId) {
        if (categoryId == null) {
            return null;
        }
        return categories.findById(categoryId)
                .orElseThrow(() -> new NotFoundException("Tuoteryhmää ei löydy: " + categoryId));
    }
}

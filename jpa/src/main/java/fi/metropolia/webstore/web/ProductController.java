package fi.metropolia.webstore.web;

import fi.metropolia.webstore.dto.ProductSearchCriteria;
import fi.metropolia.webstore.dto.Requests.PriceChangeRequest;
import fi.metropolia.webstore.dto.Requests.ProductCreateRequest;
import fi.metropolia.webstore.dto.Requests.ProductUpdateRequest;
import fi.metropolia.webstore.dto.Responses.PriceHistoryResponse;
import fi.metropolia.webstore.dto.Responses.ProductResponse;
import fi.metropolia.webstore.service.ProductService;
import jakarta.validation.Valid;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

@RestController
@RequestMapping("/api/products")
public class ProductController {

    private final ProductService products;

    public ProductController(ProductService products) {
        this.products = products;
    }

    // Kaikki hakuehdot ovat valinnaisia; haku toteutetaan Criteria API:lla.
    @GetMapping
    public List<ProductResponse> search(@RequestParam(required = false) String name,
                                        @RequestParam(required = false) Integer categoryId,
                                        @RequestParam(required = false) Integer supplierId,
                                        @RequestParam(required = false) BigDecimal minPrice,
                                        @RequestParam(required = false) BigDecimal maxPrice,
                                        @RequestParam(required = false) Boolean inStock,
                                        @RequestParam(required = false) Integer limit) {
        ProductSearchCriteria criteria = new ProductSearchCriteria(name, categoryId, supplierId, minPrice, maxPrice, inStock, limit);
        return products.search(criteria).stream().map(ProductResponse::of).toList();
    }

    @GetMapping("/{id}")
    public ProductResponse get(@PathVariable Integer id) {
        return ProductResponse.of(products.get(id));
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ProductResponse create(@Valid @RequestBody ProductCreateRequest request) {
        return ProductResponse.of(products.create(request));
    }

    @PutMapping("/{id}")
    public ProductResponse update(@PathVariable Integer id, @Valid @RequestBody ProductUpdateRequest request) {
        return ProductResponse.of(products.update(id, request));
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Integer id) {
        products.delete(id);
    }

    @PutMapping("/{id}/price")
    public ProductResponse changePrice(@PathVariable Integer id, @Valid @RequestBody PriceChangeRequest request) {
        return ProductResponse.of(products.changePrice(id, request));
    }

    @GetMapping("/{id}/price-history")
    public List<PriceHistoryResponse> priceHistory(@PathVariable Integer id) {
        return products.priceHistory(id).stream().map(PriceHistoryResponse::of).toList();
    }

    @GetMapping("/{id}/price-at")
    public PriceHistoryResponse priceAt(@PathVariable Integer id,
                                        @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime at) {
        return PriceHistoryResponse.of(products.priceAt(id, at));
    }
}

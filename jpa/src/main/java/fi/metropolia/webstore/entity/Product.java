package fi.metropolia.webstore.entity;

import jakarta.persistence.*;
import org.hibernate.annotations.DynamicUpdate;

import java.math.BigDecimal;

// @DynamicUpdate: UPDATE sisältää vain muuttuneet sarakkeet. Sovelluskäyttäjällä on
// sarakekohtainen UPDATE-oikeus, eikä price-sarakkeeseen saa kirjoittaa suoraan.
@Entity
@Table(name = "products")
@DynamicUpdate
public class Product {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(name = "name", nullable = false)
    private String name;

    @Column(name = "description")
    private String description;

    // Hinta muuttuu vain change_product_price-proseduurilla, joka kirjaa hintahistorian.
    @Column(name = "price", nullable = false, precision = 10, scale = 2, updatable = false)
    private BigDecimal price;

    @Column(name = "stock_quantity", nullable = false)
    private int stockQuantity;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "category_id")
    private ProductCategory category;

    @Column(name = "supplier_id")
    private Integer supplierId;

    @Version
    @Column(name = "version", nullable = false)
    private int version;

    protected Product() {
    }

    public Product(String name, BigDecimal price, int stockQuantity) {
        this.name = name;
        this.price = price;
        this.stockQuantity = stockQuantity;
    }

    public Product(String name, String description, BigDecimal price, int stockQuantity,
                   ProductCategory category, Integer supplierId) {
        this(name, price, stockQuantity);
        this.description = description;
        this.category = category;
        this.supplierId = supplierId;
    }

    @PrePersist
    @PreUpdate
    void validateStock() {
        if (stockQuantity < 0) {
            throw new IllegalStateException("Varastosaldo ei voi olla negatiivinen: " + stockQuantity);
        }
    }

    public void decreaseStock(int quantity) {
        stockQuantity -= quantity;
    }

    public void update(String name, String description, int stockQuantity, ProductCategory category, Integer supplierId) {
        this.name = name;
        this.description = description;
        this.stockQuantity = stockQuantity;
        this.category = category;
        this.supplierId = supplierId;
    }

    public Integer getId() {
        return id;
    }

    public String getName() {
        return name;
    }

    public String getDescription() {
        return description;
    }

    public BigDecimal getPrice() {
        return price;
    }

    public int getStockQuantity() {
        return stockQuantity;
    }

    public ProductCategory getCategory() {
        return category;
    }

    public Integer getSupplierId() {
        return supplierId;
    }

    public int getVersion() {
        return version;
    }
}

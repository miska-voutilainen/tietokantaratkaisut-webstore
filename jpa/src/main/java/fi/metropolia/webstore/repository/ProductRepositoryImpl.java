package fi.metropolia.webstore.repository;

import fi.metropolia.webstore.dto.ProductSearchCriteria;
import fi.metropolia.webstore.entity.Product;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import jakarta.persistence.criteria.*;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

class ProductRepositoryImpl implements ProductRepositoryCustom {

    @PersistenceContext
    private EntityManager em;

    // Dynaaminen haku: WHERE-ehtoon tulee vain annetut rajaukset. JPQL-merkkijonon kokoaminen
    // ehto kerrallaan olisi virhealtista; Criteria API rakentaa saman tyyppiturvallisesti.
    @Override
    public List<Product> search(ProductSearchCriteria c) {
        CriteriaBuilder cb = em.getCriteriaBuilder();
        CriteriaQuery<Product> query = cb.createQuery(Product.class);
        Root<Product> product = query.from(Product.class);
        product.fetch("category", JoinType.LEFT);

        List<Predicate> where = new ArrayList<>();
        if (c.name() != null && !c.name().isBlank()) {
            where.add(cb.like(cb.lower(product.get("name")), "%" + c.name().toLowerCase(Locale.ROOT) + "%"));
        }
        if (c.categoryId() != null) {
            where.add(cb.equal(product.get("category").get("id"), c.categoryId()));
        }
        if (c.supplierId() != null) {
            where.add(cb.equal(product.get("supplierId"), c.supplierId()));
        }
        if (c.minPrice() != null) {
            where.add(cb.greaterThanOrEqualTo(product.<BigDecimal>get("price"), c.minPrice()));
        }
        if (c.maxPrice() != null) {
            where.add(cb.lessThanOrEqualTo(product.<BigDecimal>get("price"), c.maxPrice()));
        }
        if (Boolean.TRUE.equals(c.inStock())) {
            where.add(cb.greaterThan(product.<Integer>get("stockQuantity"), 0));
        }

        query.select(product)
                .where(where.toArray(Predicate[]::new))
                .orderBy(cb.asc(product.get("price")), cb.asc(product.get("id")));

        return em.createQuery(query)
                .setMaxResults(c.effectiveLimit())
                .getResultList();
    }

    // Massapäivitys CriteriaUpdatella: kaikki rajan alittavat tuotteet täydennetään yhdellä UPDATE-lauseella.
    // Versiota kasvatetaan, jotta optimistinen lukitus huomaa muutoksen myös entiteetteihin, joita
    // joku on lukenut ennen massapäivitystä.
    @Override
    public int restockLowStock(Integer supplierId, int threshold, int amount) {
        CriteriaBuilder cb = em.getCriteriaBuilder();
        CriteriaUpdate<Product> update = cb.createCriteriaUpdate(Product.class);
        Root<Product> product = update.from(Product.class);

        Path<Integer> stock = product.get("stockQuantity");
        Path<Integer> version = product.get("version");
        update.set(stock, cb.sum(stock, amount));
        update.set(version, cb.sum(version, 1));

        List<Predicate> where = new ArrayList<>();
        where.add(cb.lessThan(stock, threshold));
        if (supplierId != null) {
            where.add(cb.equal(product.get("supplierId"), supplierId));
        }
        update.where(where.toArray(Predicate[]::new));

        // Massapäivitys ohittaa persistence contextin: odottavat muutokset kirjoitetaan ensin
        // ja välimuisti tyhjennetään lopuksi, ettei vanhentuneita entiteettejä käytetä.
        em.flush();
        int updated = em.createQuery(update).executeUpdate();
        em.clear();
        return updated;
    }
}

# Massaoperaatiot JPA:ssa

Toteutus: `jpa/src/main/java/fi/metropolia/webstore/repository/` (`OrderRepository`,
`OrderItemRepository`, `ProductRepositoryImpl`) ja `service/MassOperationService.java`.
Testit: `MassOperationTest`, `ProductSearchTest`, `ApiTest` (H2) ja `MySqlIntegrationTest` (koko MySQL-kanta).
Tulosteet: `todennukset/10_jpa_testit.txt`, `09_api_demo.txt`, `09_api_demo_sovellusloki.txt`.

## Tilanteet, joissa massaoperaatio on perusteltu

| Tilanne | Silmukkaratkaisu | Massaoperaatio |
|---|---|---|
| **Vanhojen käsittelemättömien tilausten peruminen** | Haetaan kaikki `NEW`-tilaukset entiteeteiksi ja asetetaan jokaiselle tila: 1 SELECT + N UPDATEa, N oliota muistissa | Yksi `UPDATE … WHERE status = 'NEW' AND order_date < ?` (JPQL) |
| **Vähissä olevien tuotteiden täydennys** toimituksen saapuessa | Haetaan tuotteet, kasvatetaan saldoa yksi kerrallaan | Yksi `UPDATE … SET stock = stock + ? WHERE stock < ? [AND supplier_id = ?]` (CriteriaUpdate) |
| **Myynti tuoteryhmittäin** | Ladataan satojatuhansia tilausrivejä Javaan ja summataan siellä | Tietokanta suodattaa, liittää ja ryhmittelee; palautuu 10 riviä (JPQL GROUP BY) |
| **Tuotehaku usealla valinnaisella ehdolla** | Haetaan kaikki ja suodatetaan Javassa, tai kirjoitetaan jokaiselle ehtoyhdistelmälle oma kysely | Yksi dynaamisesti koottu kysely (Criteria API) |

Mittaus oikealla datalla (`MySqlIntegrationTest.loopVersusBulkUpdate`, kaksi samankokoista kuukautta):

| Tapa | Tilauksia | Lauseita | Aika |
|---|---|---|---|
| Entiteettisilmukka | 2 776 | 1 SELECT + 2 776 UPDATE | 1 169 ms |
| JPQL-massapäivitys | 2 525 | 1 UPDATE | 124 ms |

Massapäivitys oli noin 10 kertaa nopeampi, ja ero kasvaa rivimäärän mukana. Ylläpidon kannalta yksi
deklaratiivinen lause on myös helpompi lukea ja testata kuin silmukka.

## 1. JPQL `@Modifying` UPDATE: vanhojen tilausten peruminen

**Tarkoitus:** tilaukset, jotka ovat jääneet tilaan `NEW` ennen annettua päivää, perutaan yhdellä
lauseella. Ylläpito ajaa operaation `POST /api/admin/orders/cancel-stale?before=2024-06-01`.

```java
@Modifying(flushAutomatically = true, clearAutomatically = true)
@Query("""
        UPDATE Order o
           SET o.status = :newStatus
         WHERE o.status = :currentStatus
           AND o.orderDate < :cutoff
        """)
int bulkChangeStatus(@Param("currentStatus") OrderStatus currentStatus,
                     @Param("newStatus") OrderStatus newStatus,
                     @Param("cutoff") LocalDateTime cutoff);
```

```java
@Transactional
public int cancelStaleOrders(LocalDateTime cutoff) {
    long before = orders.countByStatusBefore(OrderStatus.UUSI, cutoff);
    int updated = orders.bulkChangeStatus(OrderStatus.UUSI, OrderStatus.PERUTTU, cutoff);
    ...
}
```

Hibernate tuotti yhden lauseen (`09_api_demo_sovellusloki.txt`):
`update orders o1_0 set status=? where o1_0.status=? and o1_0.order_date<?`

**Ajo ja vaikutukset (`09_api_demo.txt`):**

| status (tilaukset ennen 2024-06-01) | Ennen | Jälkeen |
|---|---|---|
| CANCELLED | 23 849 | 37 783 |
| NEW | 13 934 | 0 |
| SHIPPED | 18 986 | 18 986 |

`{"operation":"cancel-stale-orders","affectedRows":13934}`. (Luvussa 23 849 ovat mukana myös integraatiotestin aiemmin perumat tilaukset.) Integraatiotestissä 4 899 tilausta
(ennen 2024-01-01) peruttiin 235 ms:ssa, ja tilaloki-liipaisin kirjoitti jokaiselle oman rivin
(`lokirivejä +4899`). H2-testi varmistaa rajaukset: kolme vanhaa `NEW`-tilausta perutaan, mutta
tuore `NEW`- ja vanha `SHIPPED`-tilaus jäävät ennalleen. Toinen ajo päivittää 0 riviä, joten
operaatio on idempotentti.

**Havainnot:**
- `@Modifying` vaatii aktiivisen transaktion. `@Transactional` on palvelutasolla, jolloin laskenta,
  päivitys ja tarkistus kuuluvat samaan transaktioon, ja virhe peruu koko joukon.
- Massapäivitys kulkee persistence contextin ohi: muistissa olevat `Order`-oliot jäisivät vanhoiksi.
  `clearAutomatically = true` tyhjentää kontekstin, ja `flushAutomatically = true` kirjoittaa
  odottavat muutokset ennen lausetta.
- JPA:n elinkaaritapahtumat (`@PreUpdate`) eivät laukea massapäivityksessä, mutta tietokannan
  liipaisimet laukeavat. Siksi tilaloki ja saldosuoja ovat tietokannassa.
- `AttributeConverter` toimii myös JPQL-parametreissa (`OrderStatus.UUSI` → `'NEW'`).

## 2. JPQL laaja raporttihaku: myynti tuoteryhmittäin

```java
@Query("""
        SELECT new fi.metropolia.webstore.dto.CategorySales(
                   c.id, c.name, COUNT(DISTINCT o.id), SUM(oi.quantity), SUM(oi.quantity * oi.unitPrice))
          FROM OrderItem oi JOIN oi.order o JOIN oi.product p JOIN p.category c
         WHERE o.orderDate >= :from AND o.orderDate < :to AND o.status <> :excludedStatus
         GROUP BY c.id, c.name
         ORDER BY SUM(oi.quantity * oi.unitPrice) DESC
        """)
List<CategorySales> salesByCategory(...);
```

Puolen vuoden (2025-01…2025-06) raportti käsitteli 180 802 tilausriviä ja palautti 10 riviä
845 ms:ssa. Testi vertasi summaa samaan kyselyyn suoraan SQL:llä, ja summat täsmäsivät.

## 3. Criteria API: dynaaminen tuotehaku

**Mihin sopii:** hakulomake, jossa mikä tahansa ehtojen yhdistelmä voi olla käytössä (nimi, tuoteryhmä,
toimittaja, hintaväli, vain varastossa olevat). JPQL-merkkijonon kokoaminen ehto kerrallaan olisi
virhealtista ja altistaisi injektiolle. Criteria API lisää vain annetut ehdot ja sitoo arvot aina
parametreiksi.

```java
List<Predicate> where = new ArrayList<>();
if (c.name() != null && !c.name().isBlank()) {
    where.add(cb.like(cb.lower(product.get("name")), "%" + c.name().toLowerCase(Locale.ROOT) + "%"));
}
if (c.categoryId() != null) {
    where.add(cb.equal(product.get("category").get("id"), c.categoryId()));
}
if (c.minPrice() != null) {
    where.add(cb.greaterThanOrEqualTo(product.<BigDecimal>get("price"), c.minPrice()));
}
if (Boolean.TRUE.equals(c.inStock())) {
    where.add(cb.greaterThan(product.<Integer>get("stockQuantity"), 0));
}
query.select(product).where(where.toArray(Predicate[]::new))
     .orderBy(cb.asc(product.get("price")), cb.asc(product.get("id")));
```

**Testit:** `ProductSearchTest` ajaa viisi yhdistelmää tunnettua dataa vastaan
(esim. ryhmä 1 + hinta 10–100 + varastossa → `[102, 101]`; nimi `KUULO` ilman kirjainkoon merkitystä
→ `[101]`; raja 2 → 2 riviä). Oikeassa kannassa `GET /api/products?categoryId=1&maxPrice=50&inStock=true&limit=5`
palautti viisi halvinta varastossa olevaa elektroniikkatuotetta (15,21 €, 16,00 €, …).

## 4. Criteria API: CriteriaUpdate-massapäivitys

```java
CriteriaUpdate<Product> update = cb.createCriteriaUpdate(Product.class);
Root<Product> product = update.from(Product.class);
Path<Integer> stock = product.get("stockQuantity");
Path<Integer> version = product.get("version");
update.set(stock, cb.sum(stock, amount));
update.set(version, cb.sum(version, 1));
update.where(cb.lessThan(stock, threshold) /* + valinnainen supplierId */);

em.flush();
int updated = em.createQuery(update).executeUpdate();
em.clear();
```

Hibernate tuotti lauseen
`update products p1_0 set stock_quantity=(p1_0.stock_quantity+?),version=(p1_0.version+?) where p1_0.stock_quantity<?`.

**Testit ja tulokset:**
- H2: toimittajan 7 tuotteet, joiden saldo on alle 10 (2 ja 5 kpl), nousivat 22:een ja 25:een, ja
  niiden versio nousi 0 → 1. Rajan ylittävä tuote ja muiden toimittajien tuotteet pysyivät ennallaan.
- MySQL: 21 tuotetta oli alle 10 kpl, 21 päivitettiin ja jälkeenpäin 0. API-demossa raja 60 → 121 tuotetta.
- **Versio on pakko kasvattaa:** testissä käyttäjä A luki tuotteen ennen massapäivitystä ja yritti
  tallentaa sen sen jälkeen. Koska massapäivitys kasvatti versiota, A:n tallennus hylättiin
  (`OptimisticLockException`) eikä vanha saldo kirjoittunut massapäivityksen päälle. Ilman version
  kasvatusta massapäivitys olisi kadonnut.

## Yhteenveto

| Vaatimus | Toteutus |
|---|---|
| JPQL + `@Query` + `@Modifying` | `OrderRepository.bulkChangeStatus`, `ProductRepository.decreaseStockIfAvailable` |
| `@Transactional` palvelutasolla | `MassOperationService`, `OrderService` |
| JPQL laaja haku + ryhmittely | `OrderItemRepository.salesByCategory` |
| Criteria API | `ProductRepositoryImpl.search` (CriteriaQuery), `restockLowStock` (CriteriaUpdate) |
| Todennus | SELECT ennen ja jälkeen (JdbcTemplate ja mysql), yksikkö- ja integraatiotestit, sovellusloki |

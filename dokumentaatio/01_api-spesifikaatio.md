# API-spesifikaatio

REST-rajapinta verkkokaupan backendille. Pohja-URL `http://localhost:8080/api`, JSON, UTF-8.
Toteutus: `jpa/src/main/java/fi/metropolia/webstore/web/`.

## Miksi rajapinta määritellään ensin

Rajapinta on sopimus käyttöliittymän ja backendin välillä. Kun resurssit, kentät ja virhekoodit on
sovittu etukäteen, käyttöliittymä ja backend voidaan tehdä rinnakkain, ja tietokannan rakenne voidaan
muuttaa rikkomatta asiakasohjelmia. Määrittely paljastaa myös, mitä tietoja ja toimintoja kanta
oikeasti tarvitsee: esimerkiksi tilauksia ei poisteta vaan ne perutaan, joten `DELETE /orders` puuttuu
ja sovellusroolilta puuttuu tilausten DELETE-oikeus.

## Resurssit ja tietorakenteet

| Resurssi | Taulu | Keskeiset kentät |
|---|---|---|
| Asiakas | `customers` | `id`, `firstName`, `lastName`, `email` (yksilöllinen), `phone` |
| Tuote | `products` | `id`, `name`, `description`, `price`, `stockQuantity`, `categoryId`, `supplierId`, `version` |
| Tuoteryhmä | `productcategories` | `id`, `name` (vain luku) |
| Tilaus | `orders` | `id`, `customerId`, `orderDate`, `deliveryDate`, `status` (`NEW`/`SHIPPED`/`CANCELLED`) |
| Tilausrivi | `orderitems` | `productId`, `quantity`, `unitPrice` (hinta kopioidaan tilaushetkellä) |
| Hintahistoria | `product_price_history` | `price`, `validFrom`, `validTo`, `changeReason`, `changedBy` |
| Tilahistoria | `order_status_history` | `oldStatus`, `newStatus`, `changedAt`, `changedBy` |

## Päätoiminnot

### Asiakkaat `/api/customers`

| Metodi | Polku | Kuvaus | Vastaus |
|---|---|---|---|
| GET | `/api/customers?page=0&size=20` | Sivutettu lista | 200 |
| GET | `/api/customers/{id}` | Yksi asiakas | 200 / 404 |
| GET | `/api/customers/{id}/orders` | 20 viimeisintä tilausta | 200 / 404 |
| POST | `/api/customers` | Uusi asiakas | 201 / 400 / 409 (sähköposti varattu) |
| PUT | `/api/customers/{id}` | Tietojen päivitys | 200 / 400 / 404 |
| DELETE | `/api/customers/{id}` | Poisto, jos ei tilauksia | 204 / 404 / 409 |

```json
POST /api/customers
{"firstName": "Maija", "lastName": "Meikäläinen", "email": "maija@example.com", "phone": "0401234567"}
```

### Tuotteet `/api/products`

| Metodi | Polku | Kuvaus | Vastaus |
|---|---|---|---|
| GET | `/api/products?name=&categoryId=&supplierId=&minPrice=&maxPrice=&inStock=&limit=` | Dynaaminen haku, kaikki ehdot valinnaisia, oletusraja 50 (max 200) | 200 |
| GET | `/api/products/{id}` | Yksi tuote | 200 / 404 |
| POST | `/api/products` | Uusi tuote (alkuhinta mukana) | 201 / 400 |
| PUT | `/api/products/{id}` | Nimi, kuvaus, saldo, ryhmä, toimittaja | 200 / 400 / 404 / 409 (versioristiriita) |
| DELETE | `/api/products/{id}` | Poisto, jos tuotetta ei ole tilattu | 204 / 404 / 409 |
| PUT | `/api/products/{id}/price` | Hinnanmuutos syineen proseduurin kautta | 200 / 400 (sääntörike) / 404 |
| GET | `/api/products/{id}/price-history` | Koko hintahistoria | 200 / 404 |
| GET | `/api/products/{id}/price-at?at=2026-10-07T12:00:00` | Annettuna hetkenä voimassa ollut hinta | 200 / 404 |

```json
PUT /api/products/9/price
{"price": 473.90, "reason": "kampanja -10 %"}
```

### Tilaukset `/api/orders`

| Metodi | Polku | Kuvaus | Vastaus |
|---|---|---|---|
| GET | `/api/orders/{id}` | Tilaus riveineen ja summineen | 200 / 404 |
| POST | `/api/orders` | Uusi tilaus; saldot vähennetään, koko tilaus perutaan jos yksikin rivi ei riitä | 201 / 400 / 404 / 409 |
| PUT | `/api/orders/{id}/status` | Tilan muutos (`SHIPPED` asettaa toimituspäivän) | 200 / 400 / 404 / 409 |
| GET | `/api/orders/{id}/status-history` | Liipaisimen kirjaamat tilamuutokset | 200 / 404 |

```json
POST /api/orders
{"customerId": 4242, "shippingAddressId": null, "items": [{"productId": 5, "quantity": 2}]}
```

### Raportit ja ylläpidon massaoperaatiot

| Metodi | Polku | Kuvaus |
|---|---|---|
| GET | `/api/reports/sales-by-category?from=2025-01-01&to=2025-04-01` | Myynti tuoteryhmittäin, väli `[from, to)` |
| POST | `/api/admin/orders/cancel-stale?before=2024-06-01` | Perii kaikki ennen päivää jääneet `NEW`-tilaukset |
| POST | `/api/admin/products/restock` | `{"supplierId": 7, "threshold": 10, "amount": 20}` täydentää rajan alittavat saldot |

Massaoperaatiot palauttavat `{"operation": "...", "affectedRows": n}`.

### Virheet

Virheet palautetaan RFC 7807 -muodossa (`ProblemDetail`):

```json
{"title": "Conflict", "status": 409, "detail": "Varastosaldo ei riitä tuotteelle 6", "instance": "/api/orders"}
```

| Koodi | Milloin |
|---|---|
| 400 | Validointivirhe, tuntematon tila, tietokannan sääntö (`SIGNAL SQLSTATE '45000'`) |
| 404 | Resurssia ei löydy |
| 409 | Saldo ei riitä, viite-eheys estää poiston, optimistisen lukituksen versioristiriita |

## Entiteetit

`jpa/src/main/java/fi/metropolia/webstore/entity/`

- **`Customer`** on tehtävän ensimmäinen, muista riippumaton entiteetti: `@Entity`, `@Table(name = "customers")`,
  `@Id` + `@GeneratedValue(IDENTITY)` (MySQL:n AUTO_INCREMENT) ja `@Column`-määritykset pituuksineen.
- `Product`: `@ManyToOne` tuoteryhmään, `@Version`, `@DynamicUpdate` ja `price` `updatable = false`
  (hinta muuttuu vain proseduurilla), elinkaaritarkistus `@PrePersist/@PreUpdate`.
- `Order`: tila `AttributeConverter`illa (`UUSI` ↔ `'NEW'`), `@PrePersist` täyttää oletukset.
- `OrderItem`: yhdistelmäavain `@EmbeddedId` + `@MapsId`.
- `OrderStatusHistory`, `ProductPriceHistory`: `@Immutable`, koska liipaisimet kirjoittavat ne.

Toiminta on todennettu: `ApiTest` tallentaa, hakee, päivittää ja poistaa asiakkaan H2-kannassa, ja
`api_demo.ps1` tekee saman oikeaa MySQL-kantaa vasten (`todennukset/09_api_demo.txt`: `POST /api/customers`
→ 201, `id` 100001).

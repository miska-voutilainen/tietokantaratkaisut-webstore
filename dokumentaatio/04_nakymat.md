# Näkymät

Toteutus: `kanta/migraatiot/V04__nakymat.sql` ja `V07__ajastetut_tapahtumat.sql` (`v_monthly_sales`).
Testi: `kanta/testit/07_nakymat_testi.sql`, tuloste `todennukset/07_nakymat.txt`.

## Tarpeet

1. **Tuoteluettelo** tarvitsee tuotteen, tuoteryhmän nimen ja toimittajan nimen. Ilman näkymää jokainen
   kauppasivun, raportin ja ylläpitonäkymän kysely toistaisi saman kolmen taulun LEFT JOINin.
2. **Tilauksen yhteenveto** (asiakkaan nimi, rivimäärä, kappaleet, summa) tarvitaan tilauslistoissa,
   asiakaspalvelussa ja raporteissa. Summa lasketaan tilausriveistä, joten kysely vaatii liitoksen ja
   ryhmittelyn. Näkymä pitää laskentasäännön (peruttu tilaus, NULL-summat) yhdessä paikassa.
3. **Tietoturva**: raportointikäyttäjä `webstore_report` saa lukea vain näkymiä. Näkymät eivät sisällä
   asiakkaan sähköpostia, puhelinta eikä toimittajan yhteystietoja, eikä raportoija pääse perustauluihin
   (`06_oikeudet_raportointi.txt`: `SELECT … FROM customers` → ERROR 1142).
4. **Hinnanmuutokset**: hintahistoriasta näytetään uusi ja edellinen hinta rinnakkain ikkunafunktiolla
   (`LAG`), jota raportoijan ei tarvitse osata.
5. **Kuukausimyynti** koostetaulusta raportteja varten.

## Näkymät

| Näkymä | Rakenne | Käyttäjät |
|---|---|---|
| `v_product_catalog` | `products` LEFT JOIN `productcategories`, `suppliers`; lisäksi `in_stock`-lippu | sovellus, raportointi |
| `v_order_summary` | `orders` JOIN `customers` LEFT JOIN `orderitems`, GROUP BY tilaus | sovellus, raportointi |
| `v_product_price_changes` | `product_price_history` + `LAG(price)` tuotteittain | sovellus, raportointi |
| `v_monthly_sales` | `daily_sales_summary` GROUP BY kuukausi | raportointi |

```sql
CREATE OR REPLACE VIEW v_order_summary AS
SELECT o.id                              AS order_id,
       o.order_date,
       o.status,
       o.customer_id,
       CONCAT(cu.first_name, ' ', cu.last_name) AS customer_name,
       COUNT(oi.product_id)              AS item_rows,
       COALESCE(SUM(oi.quantity), 0)     AS total_quantity,
       COALESCE(SUM(oi.quantity * oi.unit_price), 0) AS total_amount
FROM orders o
JOIN customers cu ON cu.id = o.customer_id
LEFT JOIN orderitems oi ON oi.order_id = o.id
GROUP BY o.id, o.order_date, o.status, o.customer_id, cu.first_name, cu.last_name;

CREATE OR REPLACE VIEW v_product_catalog AS
SELECT p.id AS product_id, p.name AS product_name, p.price, p.stock_quantity,
       p.stock_quantity > 0 AS in_stock,
       c.id AS category_id, c.name AS category_name,
       s.id AS supplier_id, s.name AS supplier_name
FROM products p
LEFT JOIN productcategories c ON c.id = p.category_id
LEFT JOIN suppliers s ON s.id = p.supplier_id;
```

## Testit (SELECT suoraan näkymiin)

```sql
SELECT product_id, product_name, price, stock_quantity, category_name, supplier_name
FROM v_product_catalog
WHERE category_name = 'Elektroniikka' AND in_stock
ORDER BY price LIMIT 5;
```

| product_id | product_name | price | stock_quantity | category_name | supplier_name |
|---|---|---|---|---|---|
| 396 | Atomic Stone 221 | 15.21 | 296 | Elektroniikka | Baltic Timber |
| 457 | Smart Shield 677 | 16.00 | 231 | Elektroniikka | Digiworld Ltd |
| 899 | Happy Bug 816 | 24.60 | 3 | Elektroniikka | Maaseudun Koneurakointi |

```sql
SELECT * FROM v_order_summary WHERE order_id = 4242;
```

| order_id | order_date | status | customer_name | item_rows | total_quantity | total_amount |
|---|---|---|---|---|---|---|
| 4242 | 2025-10-20 12:26:51 | SHIPPED | Barbara Griffith | 9 | 31 | 14495.26 |

Asiakkaan 49977 kaikki 12 tilausta summineen saadaan yhdellä ehdolla `WHERE customer_id = 49977`.

**Suorituskyky:** `EXPLAIN` näyttää yksittäisen tilauksen haulle `Rows fetched before execution`.
MySQL 8 työntää ehdon `order_id = ?` ryhmittelyn sisään (derived condition pushdown), joten näkymää
käytettäessä ei lasketa kaikkia 200 000 tilausta. Koko kannan kattavat koosteet haetaan sen sijaan
`v_monthly_sales`-näkymästä, joka lukee valmiiksi koostettua taulua.

Raportointikäyttäjä luki `v_monthly_sales`-näkymää (2025-11: 814 tilausta, 6 368 229,68 €) ja
`v_order_summary`-näkymää, vaikka sillä ei ole oikeutta yhteenkään perustauluun. Näkymät ajetaan
luojansa oikeuksin (`SQL SECURITY DEFINER`).

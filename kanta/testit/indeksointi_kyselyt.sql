-- Verkkokaupan tavanomaiset hakukyselyt. Sovelluksesta tulevat parametrit on kovakoodattu esimerkkiarvoiksi.
-- Ajo: mysql ... webstore < indeksointi_kyselyt.sql  (EXPLAIN ANALYZE näyttää suunnitelman ja todellisen ajan)
USE webstore;

-- Q1 Kirjautuminen: asiakas sähköpostiosoitteella.
EXPLAIN ANALYZE
SELECT id, first_name, last_name
FROM customers
WHERE email = 'erinbaker4242@example.net';

-- Q2 Asiakaspalvelu: asiakkaan haku sukunimellä ja etunimen alulla.
EXPLAIN ANALYZE
SELECT id, first_name, last_name, email
FROM customers
WHERE last_name = 'Smith' AND first_name LIKE 'Mich%'
ORDER BY first_name;

-- Q3 Oma tili: asiakkaan 20 viimeisintä tilausta.
EXPLAIN ANALYZE
SELECT id, order_date, status
FROM orders
WHERE customer_id = 49977
ORDER BY order_date DESC
LIMIT 20;

-- Q4 Tilauksen tiedot: tilausrivit tuotetietoineen.
EXPLAIN ANALYZE
SELECT oi.product_id, p.name, oi.quantity, oi.unit_price
FROM orderitems oi
JOIN products p ON p.id = oi.product_id
WHERE oi.order_id = 4242;

-- Q5 Kauppa: tuoteryhmän 20 halvinta tuotetta.
EXPLAIN ANALYZE
SELECT id, name, price
FROM products
WHERE category_id = 3
ORDER BY price
LIMIT 20;

-- Q6 Hakukenttä: tuotteet nimen alun perusteella.
EXPLAIN ANALYZE
SELECT id, name, price
FROM products
WHERE name LIKE 'Quantum%';

-- Q7 Varasto: vähissä olevat tuotteet.
EXPLAIN ANALYZE
SELECT id, name, stock_quantity
FROM products
WHERE stock_quantity < 10
ORDER BY stock_quantity;

-- Q8 Tilausten käsittely: 50 uusinta käsittelemätöntä tilausta.
EXPLAIN ANALYZE
SELECT id, customer_id, order_date
FROM orders
WHERE status = 'NEW'
ORDER BY order_date DESC
LIMIT 50;

-- Q9 Kuukausiraportti: tammikuun 2025 tilausmäärä.
EXPLAIN ANALYZE
SELECT COUNT(*)
FROM orders
WHERE order_date >= '2025-01-01' AND order_date < '2025-02-01';

-- Q10 Tuotteen myyntihistoria.
EXPLAIN ANALYZE
SELECT order_id, quantity, unit_price
FROM orderitems
WHERE product_id = 1;

-- Q11 Toimitusosoitteen valinta: asiakkaan osoitteet.
EXPLAIN ANALYZE
SELECT id, street_address, postal_code, city
FROM customeraddresses
WHERE customer_id = 4242;

-- Q12 Hankinta: toimittajan tuotteet.
EXPLAIN ANALYZE
SELECT id, name, stock_quantity
FROM products
WHERE supplier_id = 52;

-- Q13 Raportti: 10 myydyintä tuotetta.
EXPLAIN ANALYZE
SELECT product_id, SUM(quantity) AS sold
FROM orderitems
GROUP BY product_id
ORDER BY sold DESC
LIMIT 10;

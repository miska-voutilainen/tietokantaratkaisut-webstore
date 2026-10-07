-- Näkymien testi: haut kohdistetaan suoraan näkymiin.
USE webstore;

-- Tuoteluettelo: Elektroniikka-ryhmän halvimmat varastossa olevat tuotteet.
SELECT product_id, product_name, price, stock_quantity, category_name, supplier_name
FROM v_product_catalog
WHERE category_name = 'Elektroniikka' AND in_stock
ORDER BY price
LIMIT 5;

-- Yksittäisen tilauksen yhteenveto.
SELECT * FROM v_order_summary WHERE order_id = 4242;

-- Asiakkaan tilaukset summineen.
SELECT order_id, order_date, status, item_rows, total_amount
FROM v_order_summary
WHERE customer_id = 49977
ORDER BY order_date DESC;

-- Ehto työntyy ryhmittelyn sisään: vain yksi tilaus käsitellään, ei 200 000.
EXPLAIN FORMAT=TREE SELECT * FROM v_order_summary WHERE order_id = 4242;

-- Kuukausimyynti koostetaulusta.
SELECT * FROM v_monthly_sales WHERE sales_month BETWEEN '2025-01' AND '2025-06' ORDER BY sales_month;

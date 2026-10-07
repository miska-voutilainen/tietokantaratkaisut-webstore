-- V04 Näkymät. Perustelut: dokumentaatio/04_nakymat.md

-- Tuoteluettelo kategoria- ja toimittajanimineen. Kauppasivu ja raporttikäyttäjä lukevat tätä
-- kolmen taulun liitoksen sijaan, eikä toimittajan yhteystietoja paljasteta.
CREATE OR REPLACE VIEW v_product_catalog AS
SELECT p.id            AS product_id,
       p.name          AS product_name,
       p.price,
       p.stock_quantity,
       p.stock_quantity > 0 AS in_stock,
       c.id            AS category_id,
       c.name          AS category_name,
       s.id            AS supplier_id,
       s.name          AS supplier_name
FROM products p
LEFT JOIN productcategories c ON c.id = p.category_id
LEFT JOIN suppliers s ON s.id = p.supplier_id;

-- Tilauksen yhteenveto: asiakas, rivimäärä, kappalemäärä ja summa.
-- Ehto order_id = ? työntyy MySQL 8:ssa ryhmittelyn sisään (derived condition pushdown),
-- joten yksittäisen tilauksen haku ei laske kaikkia tilauksia.
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

-- Hinta-ajan tarkastelu: nykyinen hinta ja edellinen hinta rinnakkain.
CREATE OR REPLACE VIEW v_product_price_changes AS
SELECT h.product_id,
       p.name AS product_name,
       h.price AS new_price,
       LAG(h.price) OVER (PARTITION BY h.product_id ORDER BY h.valid_from) AS previous_price,
       h.valid_from AS changed_at,
       h.change_reason,
       h.changed_by
FROM product_price_history h
JOIN products p ON p.id = h.product_id;

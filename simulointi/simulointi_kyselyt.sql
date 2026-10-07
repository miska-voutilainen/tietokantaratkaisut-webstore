-- Q1: Vahissa olevat tuotteet
SELECT id, name, price, stock_quantity
FROM products
WHERE stock_quantity < 10
ORDER BY stock_quantity ASC, id ASC
LIMIT 10;

-- Q2: Tilausrivit asiakkaan ja tuotteen tiedoilla
SELECT o.id AS order_id,
       CONCAT(c.first_name, ' ', c.last_name) AS customer,
       p.name AS product,
       oi.quantity,
       oi.unit_price,
       ROUND(oi.quantity * oi.unit_price, 2) AS row_total
FROM orders AS o
INNER JOIN customers AS c ON c.id = o.customer_id
INNER JOIN orderitems AS oi ON oi.order_id = o.id
INNER JOIN products AS p ON p.id = oi.product_id
WHERE o.id <= 3
ORDER BY o.id, p.id
LIMIT 10;

-- Q3: Asiakkaat, joilla ei ole tilauksia
SELECT c.id,
       CONCAT(c.first_name, ' ', c.last_name) AS customer,
       c.email
FROM customers AS c
LEFT JOIN orders AS o ON o.customer_id = c.id
WHERE o.id IS NULL
ORDER BY c.id
LIMIT 10;

-- Q4: Tuoteryhmien tuote- ja hintakooste
SELECT pc.name AS category,
       COUNT(p.id) AS product_count,
       ROUND(AVG(p.price), 2) AS average_price
FROM productcategories AS pc
INNER JOIN products AS p ON p.category_id = pc.id
GROUP BY pc.id, pc.name
HAVING AVG(p.price) > 500
ORDER BY average_price DESC;

-- Q5: Keskihintaa kalliimmat tuotteet
SELECT id, name, price
FROM products
WHERE price > (SELECT AVG(price) FROM products)
ORDER BY price DESC, id ASC
LIMIT 10;

-- Q6: Lahetetyt tilaukset uusimmasta vanhimpaan
SELECT o.id,
       o.customer_id,
       o.order_date,
       o.status
FROM orders AS o
WHERE o.status = 'SHIPPED'
  AND o.order_date >= '2025-01-01'
ORDER BY o.order_date DESC
LIMIT 50;

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

SELECT c.id,
       CONCAT(c.first_name, ' ', c.last_name) AS customer,
       c.email
FROM customers AS c
LEFT JOIN orders AS o ON o.customer_id = c.id
WHERE o.id IS NULL
ORDER BY c.id
LIMIT 10;

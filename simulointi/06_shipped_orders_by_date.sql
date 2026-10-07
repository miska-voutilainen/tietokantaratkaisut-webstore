SELECT o.id,
       o.customer_id,
       o.order_date,
       o.status
FROM orders AS o
WHERE o.status = 'SHIPPED'
  AND o.order_date >= '2025-01-01'
ORDER BY o.order_date DESC
LIMIT 50;

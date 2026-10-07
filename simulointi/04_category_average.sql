SELECT pc.name AS category,
       COUNT(p.id) AS product_count,
       ROUND(AVG(p.price), 2) AS average_price
FROM productcategories AS pc
INNER JOIN products AS p ON p.category_id = pc.id
GROUP BY pc.id, pc.name
HAVING AVG(p.price) > 500
ORDER BY average_price DESC;

SELECT id, name, price
FROM products
WHERE price > (SELECT AVG(price) FROM products)
ORDER BY price DESC, id ASC
LIMIT 10;

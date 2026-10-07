SELECT id, name, price, stock_quantity
FROM products
WHERE stock_quantity < 10
ORDER BY stock_quantity ASC, id ASC
LIMIT 10;

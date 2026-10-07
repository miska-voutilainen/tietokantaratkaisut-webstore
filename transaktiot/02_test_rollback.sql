USE webstore;

SET @test_customer_id = 1;
SET @test_product_id = 1;
SET @test_quantity = 2;

SELECT stock_quantity INTO @stock_before
FROM products
WHERE id = @test_product_id;

SELECT COUNT(*) INTO @orders_before
FROM orders;

SELECT COUNT(*) INTO @items_before
FROM orderitems;

SELECT
    @stock_before AS stock_before,
    @orders_before AS orders_before,
    @items_before AS items_before;

CALL place_order_transaction(
    @test_customer_id,
    @test_product_id,
    @test_quantity,
    TRUE
);

SELECT
    @stock_before AS stock_before,
    (SELECT stock_quantity FROM products WHERE id = @test_product_id) AS stock_after,
    @orders_before AS orders_before,
    (SELECT COUNT(*) FROM orders) AS orders_after,
    @items_before AS items_before,
    (SELECT COUNT(*) FROM orderitems) AS items_after;

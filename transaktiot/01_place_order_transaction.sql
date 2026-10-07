USE webstore;

DROP PROCEDURE IF EXISTS place_order_transaction;

DELIMITER //

CREATE PROCEDURE place_order_transaction(
    IN p_customer_id INT,
    IN p_product_id INT,
    IN p_quantity INT,
    IN p_simulate_error BOOLEAN
)
BEGIN
    DECLARE v_price DECIMAL(10,2) DEFAULT NULL;
    DECLARE v_stock INT DEFAULT NULL;
    DECLARE v_order_id INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT price, stock_quantity
      INTO v_price, v_stock
      FROM products
     WHERE id = p_product_id
       FOR UPDATE;

    IF v_stock IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Tuotetta ei löydy';
    END IF;

    IF p_quantity <= 0 OR v_stock < p_quantity THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Varastosaldo ei riitä';
    END IF;

    INSERT INTO orders (customer_id, status)
    VALUES (p_customer_id, 'NEW');

    SET v_order_id = LAST_INSERT_ID();

    UPDATE products
       SET stock_quantity = stock_quantity - p_quantity
     WHERE id = p_product_id;

    IF p_simulate_error THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Simuloitu virhe ennen tilausrivin tallennusta';
    END IF;

    INSERT INTO orderitems (order_id, product_id, quantity, unit_price)
    VALUES (v_order_id, p_product_id, p_quantity, v_price);

    COMMIT;

    SELECT v_order_id AS created_order_id;
END//

DELIMITER ;

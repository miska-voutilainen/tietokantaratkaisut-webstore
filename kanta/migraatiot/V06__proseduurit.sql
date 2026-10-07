-- V06 Tallennetut proseduurit.

DELIMITER //

-- Transaktiotehtävän tilausproseduuri: saldo luetaan FOR UPDATE -lukolla, ja virhe peruu kaiken.
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
       SET stock_quantity = stock_quantity - p_quantity,
           version = version + 1
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

-- Tietoturvaproseduuri: sovelluskäyttäjällä ei ole UPDATE-oikeutta products.price-sarakkeeseen,
-- joten hinta voi muuttua vain tämän tarkistetun polun kautta. SQL SECURITY DEFINER ajaa
-- päivityksen proseduurin omistajan oikeuksin; hintahistoria tallentaa syyn ja todellisen käyttäjän.
CREATE PROCEDURE change_product_price(
    IN p_product_id INT,
    IN p_new_price DECIMAL(10,2),
    IN p_reason VARCHAR(255)
)
SQL SECURITY DEFINER
BEGIN
    DECLARE v_old_price DECIMAL(10,2) DEFAULT NULL;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @price_change_reason = NULL;
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_new_price IS NULL OR p_new_price <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Hinnan on oltava positiivinen';
    END IF;

    IF p_reason IS NULL OR TRIM(p_reason) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Hinnanmuutokselle on annettava syy';
    END IF;

    START TRANSACTION;

    SELECT price INTO v_old_price
      FROM products
     WHERE id = p_product_id
       FOR UPDATE;

    IF v_old_price IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tuotetta ei löydy';
    END IF;

    -- Yli puolet kerralla muuttuva hinta on todennäköisesti näppäilyvirhe.
    IF p_new_price > v_old_price * 1.5 OR p_new_price < v_old_price * 0.5 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Hinta saa muuttua kerralla enintään 50 %';
    END IF;

    SET @price_change_reason = p_reason;

    UPDATE products
       SET price = p_new_price,
           version = version + 1
     WHERE id = p_product_id;

    SET @price_change_reason = NULL;
    COMMIT;
END//

DELIMITER ;

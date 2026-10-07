-- V03 Temporaalinen hintahistoria. Jokainen hinta on voimassa aikavälin [valid_from, valid_to).
-- valid_to IS NULL tarkoittaa nykyistä hintaa.

CREATE TABLE product_price_history (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    valid_from DATETIME(6) NOT NULL,
    valid_to DATETIME(6) NULL,
    change_reason VARCHAR(255) NULL,
    changed_by VARCHAR(288) NOT NULL,
    CONSTRAINT fk_price_history_product
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE,
    INDEX idx_price_history_product_time (product_id, valid_from, valid_to)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Nykyiset hinnat ovat historian ensimmäiset rivit. Aiempaa hintatietoa ei aineistossa ole.
INSERT INTO product_price_history (product_id, price, valid_from, valid_to, change_reason, changed_by)
SELECT id, price, NOW(6), NULL, 'alkuarvo asennuksessa', CURRENT_USER()
FROM products;

DELIMITER //

-- Uusi tuote saa heti avoimen hintarivin.
CREATE TRIGGER trg_products_price_history_insert
AFTER INSERT ON products
FOR EACH ROW
BEGIN
    INSERT INTO product_price_history (product_id, price, valid_from, change_reason, changed_by)
    VALUES (NEW.id, NEW.price, NOW(6), 'uusi tuote', USER());
END//

-- Hinnan muuttuessa edellinen rivi suljetaan ja uusi avataan samalla aikaleimalla.
-- Syy tulee istuntomuuttujasta, jonka change_product_price-proseduuri asettaa.
CREATE TRIGGER trg_products_price_history_update
AFTER UPDATE ON products
FOR EACH ROW
BEGIN
    DECLARE v_now DATETIME(6) DEFAULT NOW(6);

    IF NEW.price <> OLD.price THEN
        UPDATE product_price_history
           SET valid_to = v_now
         WHERE product_id = NEW.id
           AND valid_to IS NULL;

        INSERT INTO product_price_history (product_id, price, valid_from, change_reason, changed_by)
        VALUES (NEW.id, NEW.price, v_now, COALESCE(@price_change_reason, 'suora UPDATE'), USER());
    END IF;
END//

DELIMITER ;

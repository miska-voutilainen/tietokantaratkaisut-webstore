-- V05 Liipaisimet: tilauksen tilamuutosten loki ja varastosaldon suoja.

CREATE TABLE order_status_history (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    old_status VARCHAR(50) NULL,
    new_status VARCHAR(50) NULL,
    changed_at DATETIME(6) NOT NULL,
    changed_by VARCHAR(288) NOT NULL,
    CONSTRAINT fk_status_history_order
        FOREIGN KEY (order_id) REFERENCES orders (id),
    INDEX idx_status_history_order (order_id, changed_at),
    INDEX idx_status_history_changed_at (changed_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DELIMITER //

CREATE TRIGGER trg_orders_status_log_insert
AFTER INSERT ON orders
FOR EACH ROW
BEGIN
    INSERT INTO order_status_history (order_id, old_status, new_status, changed_at, changed_by)
    VALUES (NEW.id, NULL, NEW.status, NOW(6), USER());
END//

-- <=> on NULL-turvallinen vertailu, joten myös muutos NULL-arvosta kirjautuu.
CREATE TRIGGER trg_orders_status_log_update
AFTER UPDATE ON orders
FOR EACH ROW
BEGIN
    IF NOT (NEW.status <=> OLD.status) THEN
        INSERT INTO order_status_history (order_id, old_status, new_status, changed_at, changed_by)
        VALUES (NEW.id, OLD.status, NEW.status, NOW(6), USER());
    END IF;
END//

-- Viimeinen suoja ylimyyntiä vastaan: koskee myös SQL-työkaluja ja JPA:n massapäivityksiä,
-- jotka ohittavat entiteetin @PreUpdate-tarkistuksen.
CREATE TRIGGER trg_products_stock_guard
BEFORE UPDATE ON products
FOR EACH ROW
BEGIN
    IF NEW.stock_quantity < 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Varastosaldo ei voi olla negatiivinen';
    END IF;
END//

DELIMITER ;

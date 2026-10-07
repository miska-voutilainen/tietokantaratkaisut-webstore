-- Koottu tiedostoista kanta/migraatiot/V*.sql. Älä muokkaa käsin, aja kanta/asenna.ps1.
USE webstore;

-- ===== V01__tuotteen_versio.sql =====
-- V01 Optimistisen lukituksen versiosarake (JPA @Version). Olemassa olevat rivit saavat version 0.
ALTER TABLE products
    ADD COLUMN version INT NOT NULL DEFAULT 0;

-- ===== V02__indeksit.sql =====
-- V02 Indeksointisuunnitelman indeksit. Perustelut: dokumentaatio/02_indeksointi.md

-- Q1 kirjautuminen sähköpostilla; samalla estetään saman osoitteen kaksoisrekisteröinti.
CREATE UNIQUE INDEX uk_customers_email ON customers (email);

-- Q2 asiakkaan haku nimellä (sukunimi tarkka, etunimen alku).
CREATE INDEX idx_customers_name ON customers (last_name, first_name);

-- Q3 asiakkaan tilaushistoria uusin ensin. Korvaa vierasavaimen yksisarakkeisen indeksin.
CREATE INDEX idx_orders_customer_date ON orders (customer_id, order_date);
DROP INDEX fk_order_customer ON orders;

-- Q8 tilan mukaan suodatettu, päivämäärällä järjestetty tilauslista (simulointitehtävän indeksi).
CREATE INDEX idx_orders_status_order_date ON orders (status, order_date DESC);

-- Q9 aikavälin raportit ja massapäivitykset, jotka rajautuvat tilauspäivään.
CREATE INDEX idx_orders_order_date ON orders (order_date);

-- Q5 tuoteryhmän tuotteet hintajärjestyksessä. Korvaa vierasavaimen indeksin.
CREATE INDEX idx_products_category_price ON products (category_id, price);
DROP INDEX fk_product_category ON products;

-- Q6 tuotehaku nimen alulla.
CREATE INDEX idx_products_name ON products (name);

-- ===== V03__hintahistoria.sql =====
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

-- ===== V04__nakymat.sql =====
-- V04 Näkymät. Perustelut: dokumentaatio/04_nakymat.md

-- Tuoteluettelo kategoria- ja toimittajanimineen. Kauppasivu ja raporttikäyttäjä lukevat tätä
-- kolmen taulun liitoksen sijaan, eikä toimittajan yhteystietoja paljasteta.
CREATE OR REPLACE VIEW v_product_catalog AS
SELECT p.id            AS product_id,
       p.name          AS product_name,
       p.price,
       p.stock_quantity,
       p.stock_quantity > 0 AS in_stock,
       c.id            AS category_id,
       c.name          AS category_name,
       s.id            AS supplier_id,
       s.name          AS supplier_name
FROM products p
LEFT JOIN productcategories c ON c.id = p.category_id
LEFT JOIN suppliers s ON s.id = p.supplier_id;

-- Tilauksen yhteenveto: asiakas, rivimäärä, kappalemäärä ja summa.
-- Ehto order_id = ? työntyy MySQL 8:ssa ryhmittelyn sisään (derived condition pushdown),
-- joten yksittäisen tilauksen haku ei laske kaikkia tilauksia.
CREATE OR REPLACE VIEW v_order_summary AS
SELECT o.id                              AS order_id,
       o.order_date,
       o.status,
       o.customer_id,
       CONCAT(cu.first_name, ' ', cu.last_name) AS customer_name,
       COUNT(oi.product_id)              AS item_rows,
       COALESCE(SUM(oi.quantity), 0)     AS total_quantity,
       COALESCE(SUM(oi.quantity * oi.unit_price), 0) AS total_amount
FROM orders o
JOIN customers cu ON cu.id = o.customer_id
LEFT JOIN orderitems oi ON oi.order_id = o.id
GROUP BY o.id, o.order_date, o.status, o.customer_id, cu.first_name, cu.last_name;

-- Hinta-ajan tarkastelu: nykyinen hinta ja edellinen hinta rinnakkain.
CREATE OR REPLACE VIEW v_product_price_changes AS
SELECT h.product_id,
       p.name AS product_name,
       h.price AS new_price,
       LAG(h.price) OVER (PARTITION BY h.product_id ORDER BY h.valid_from) AS previous_price,
       h.valid_from AS changed_at,
       h.change_reason,
       h.changed_by
FROM product_price_history h
JOIN products p ON p.id = h.product_id;

-- ===== V05__liipaisimet.sql =====
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

-- ===== V06__proseduurit.sql =====
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

-- ===== V07__ajastetut_tapahtumat.sql =====
-- V07 Päivittäinen myyntikooste ajastettuna tapahtumana. Vaatii event_scheduler = ON (MySQL 8:n oletus).

-- Raportit lukevat tätä 1,1 miljoonan tilausrivin koostamisen sijaan.
CREATE TABLE daily_sales_summary (
    sales_date DATE PRIMARY KEY,
    order_count INT NOT NULL,
    item_count INT NOT NULL,
    revenue DECIMAL(14,2) NOT NULL,
    refreshed_at DATETIME(6) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE event_run_log (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    event_name VARCHAR(64) NOT NULL,
    started_at DATETIME(6) NOT NULL,
    finished_at DATETIME(6) NOT NULL,
    rows_affected INT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DELIMITER //

-- Laskee koosteen uudelleen päivästä p_from alkaen. Peruttuja tilauksia ei lasketa myynniksi.
CREATE PROCEDURE refresh_daily_sales(IN p_from DATE)
BEGIN
    DELETE FROM daily_sales_summary WHERE sales_date >= p_from;

    INSERT INTO daily_sales_summary (sales_date, order_count, item_count, revenue, refreshed_at)
    SELECT DATE(o.order_date),
           COUNT(DISTINCT o.id),
           COALESCE(SUM(oi.quantity), 0),
           COALESCE(SUM(oi.quantity * oi.unit_price), 0),
           NOW(6)
    FROM orders o
    LEFT JOIN orderitems oi ON oi.order_id = o.id
    WHERE o.order_date >= p_from
      AND o.status <> 'CANCELLED'
    GROUP BY DATE(o.order_date);
END//

DELIMITER ;

-- Alkutäyttö koko historialle.
CALL refresh_daily_sales('2000-01-01');

DELIMITER //

-- Joka yö klo 02.00: viimeiset 7 päivää lasketaan uudelleen, koska tilauksia voidaan perua jälkikäteen.
CREATE EVENT ev_refresh_daily_sales
ON SCHEDULE EVERY 1 DAY
STARTS (CURRENT_DATE + INTERVAL 1 DAY + INTERVAL 2 HOUR)
ON COMPLETION PRESERVE
COMMENT 'Päivittäisen myyntikoosteen päivitys'
DO
BEGIN
    DECLARE v_started DATETIME(6) DEFAULT NOW(6);

    CALL refresh_daily_sales(CURRENT_DATE - INTERVAL 7 DAY);

    INSERT INTO event_run_log (event_name, started_at, finished_at, rows_affected)
    SELECT 'ev_refresh_daily_sales', v_started, NOW(6), COUNT(*)
    FROM daily_sales_summary
    WHERE sales_date >= CURRENT_DATE - INTERVAL 7 DAY;
END//

-- Kerran kuukaudessa: yli 3 vuotta vanhat tilaloki- ja ajolokirivit poistetaan.
CREATE EVENT ev_purge_old_logs
ON SCHEDULE EVERY 1 MONTH
STARTS (LAST_DAY(CURRENT_DATE) + INTERVAL 1 DAY + INTERVAL 3 HOUR)
ON COMPLETION PRESERVE
COMMENT 'Vanhojen lokirivien poisto'
DO
BEGIN
    DECLARE v_started DATETIME(6) DEFAULT NOW(6);
    DECLARE v_deleted INT DEFAULT 0;

    DELETE FROM order_status_history WHERE changed_at < NOW() - INTERVAL 3 YEAR;
    SET v_deleted = ROW_COUNT();
    DELETE FROM event_run_log WHERE started_at < NOW() - INTERVAL 3 YEAR;
    SET v_deleted = v_deleted + ROW_COUNT();

    INSERT INTO event_run_log (event_name, started_at, finished_at, rows_affected)
    VALUES ('ev_purge_old_logs', v_started, NOW(6), v_deleted);
END//

DELIMITER ;

-- Kuukausimyynti suoraan koostetaulusta.
CREATE OR REPLACE VIEW v_monthly_sales AS
SELECT DATE_FORMAT(sales_date, '%Y-%m') AS sales_month,
       SUM(order_count) AS order_count,
       SUM(item_count)  AS item_count,
       SUM(revenue)     AS revenue
FROM daily_sales_summary
GROUP BY DATE_FORMAT(sales_date, '%Y-%m');

-- ===== V08__kayttajat_ja_roolit.sql =====
-- V08 Roolit ja käyttäjät. Perustelut: dokumentaatio/07_kayttajat_varmuuskopiointi_skeemamuutokset.md
-- Salasanat ovat paikkamerkkejä, jotka asenna.ps1 korvaa.

DROP USER IF EXISTS 'webstore_admin'@'localhost', 'webstore_app'@'localhost', 'webstore_report'@'localhost';
DROP ROLE IF EXISTS 'webstore_admin_role', 'webstore_app_role', 'webstore_report_role';

CREATE ROLE 'webstore_admin_role', 'webstore_app_role', 'webstore_report_role';

-- Ylläpitäjä: kaikki oikeudet tähän skeemaan (taulut, näkymät, liipaisimet, tapahtumat, rutiinit),
-- mutta ei palvelintason oikeuksia eikä muita tietokantoja.
GRANT ALL PRIVILEGES ON webstore.* TO 'webstore_admin_role';

-- Sovellus (Spring Boot -backend): vain ne taulut ja toiminnot, joita API käyttää.
GRANT SELECT, INSERT, UPDATE, DELETE ON webstore.customers TO 'webstore_app_role';
GRANT SELECT, INSERT, UPDATE, DELETE ON webstore.customeraddresses TO 'webstore_app_role';
GRANT SELECT ON webstore.productcategories TO 'webstore_app_role';
GRANT SELECT ON webstore.suppliers TO 'webstore_app_role';
GRANT SELECT, INSERT, UPDATE, DELETE ON webstore.products TO 'webstore_app_role';
GRANT SELECT, INSERT ON webstore.orderitems TO 'webstore_app_role';
-- Tilauksia ei poisteta vaan ne perutaan, joten DELETE-oikeutta ei anneta.
GRANT SELECT, INSERT, UPDATE (status, delivery_date, shipping_address_id) ON webstore.orders TO 'webstore_app_role';
GRANT SELECT ON webstore.order_status_history TO 'webstore_app_role';
GRANT SELECT ON webstore.product_price_history TO 'webstore_app_role';
GRANT SELECT ON webstore.daily_sales_summary TO 'webstore_app_role';
GRANT SELECT ON webstore.v_product_catalog TO 'webstore_app_role';
GRANT SELECT ON webstore.v_order_summary TO 'webstore_app_role';
GRANT SELECT ON webstore.v_product_price_changes TO 'webstore_app_role';
GRANT EXECUTE ON PROCEDURE webstore.place_order_transaction TO 'webstore_app_role';
GRANT EXECUTE ON PROCEDURE webstore.change_product_price TO 'webstore_app_role';

-- Hinnan suora muuttaminen poistetaan: taulutason UPDATE perutaan ja tilalle annetaan
-- sarakekohtainen UPDATE ilman price-saraketta. Hinta muuttuu vain change_product_price-proseduurilla.
REVOKE UPDATE ON webstore.products FROM 'webstore_app_role';
GRANT UPDATE (name, description, stock_quantity, category_id, supplier_id, version)
    ON webstore.products TO 'webstore_app_role';

-- Raportointi: vain lukuoikeus näkymiin ja koosteisiin. Ei pääsyä asiakkaiden yhteystietoihin.
GRANT SELECT ON webstore.v_product_catalog TO 'webstore_report_role';
GRANT SELECT ON webstore.v_order_summary TO 'webstore_report_role';
GRANT SELECT ON webstore.v_monthly_sales TO 'webstore_report_role';
GRANT SELECT ON webstore.v_product_price_changes TO 'webstore_report_role';
GRANT SELECT ON webstore.daily_sales_summary TO 'webstore_report_role';

CREATE USER 'webstore_admin'@'localhost' IDENTIFIED BY '__ADMIN_PASSWORD__';
CREATE USER 'webstore_app'@'localhost' IDENTIFIED BY '__APP_PASSWORD__';
CREATE USER 'webstore_report'@'localhost' IDENTIFIED BY '__REPORT_PASSWORD__';

GRANT 'webstore_admin_role' TO 'webstore_admin'@'localhost';
GRANT 'webstore_app_role' TO 'webstore_app'@'localhost';
GRANT 'webstore_report_role' TO 'webstore_report'@'localhost';

SET DEFAULT ROLE ALL TO 'webstore_admin'@'localhost', 'webstore_app'@'localhost', 'webstore_report'@'localhost';

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

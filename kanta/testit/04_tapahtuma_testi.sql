-- Ajastetun tapahtuman testi. Tapahtuma ajastetaan hetkeksi käynnistymään 3 sekunnin päästä,
-- todetaan vaikutus ja palautetaan yöllinen aikataulu. Ajetaan asennustilillä (root),
-- koska tapahtuman omistaja (DEFINER) on root ja sen muuttaminen vaatii SYSTEM_USER-oikeuden.
USE webstore;

SELECT @@event_scheduler AS event_scheduler;

-- Tämän päivän tilaus, jota koosteessa ei vielä ole.
INSERT INTO orders (customer_id, status) VALUES (4242, 'NEW');
INSERT INTO orderitems (order_id, product_id, quantity, unit_price)
VALUES (LAST_INSERT_ID(), 3, 2, 849.66);

SELECT 'ennen' AS vaihe, s.* FROM daily_sales_summary s WHERE sales_date = CURRENT_DATE;
SELECT COUNT(*) AS ajoja_lokissa_ennen FROM event_run_log WHERE event_name = 'ev_refresh_daily_sales';

ALTER EVENT ev_refresh_daily_sales
    ON SCHEDULE EVERY 1 DAY STARTS CURRENT_TIMESTAMP + INTERVAL 3 SECOND;
DO SLEEP(6);

SELECT 'jälkeen' AS vaihe, s.* FROM daily_sales_summary s WHERE sales_date = CURRENT_DATE;
SELECT event_name, started_at, finished_at, rows_affected
FROM event_run_log
ORDER BY id DESC
LIMIT 3;

SELECT event_name, status, interval_value, interval_field, last_executed
FROM information_schema.events
WHERE event_schema = 'webstore';

-- Palautetaan normaali aikataulu: joka yö klo 02.00.
ALTER EVENT ev_refresh_daily_sales
    ON SCHEDULE EVERY 1 DAY STARTS (CURRENT_DATE + INTERVAL 1 DAY + INTERVAL 2 HOUR);

SELECT event_name, starts FROM information_schema.events WHERE event_name = 'ev_refresh_daily_sales';

-- Raportointikäyttäjän (webstore_report) testi. Ajetaan --force-valitsimella.
USE webstore;

SELECT CURRENT_USER() AS kayttaja;

-- Sallittu: näkymät ja koosteet.
SELECT * FROM v_monthly_sales ORDER BY sales_month DESC LIMIT 3;
SELECT * FROM v_order_summary WHERE order_id = 4242;

-- Kielletty: perustaulut ja asiakkaiden yhteystiedot -> ERROR 1142.
SELECT email, phone FROM customers LIMIT 1;
-- Kielletty: kaikki muutokset -> ERROR 1142.
UPDATE daily_sales_summary SET revenue = 0;

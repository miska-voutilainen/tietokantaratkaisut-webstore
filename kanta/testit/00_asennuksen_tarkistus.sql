-- Asennuksen jälkeinen tarkistus: kaikki osat ovat paikallaan.
SELECT 'taulut' AS kohde, COUNT(*) AS lkm
  FROM information_schema.tables WHERE table_schema = 'webstore' AND table_type = 'BASE TABLE'
UNION ALL
SELECT 'näkymät', COUNT(*) FROM information_schema.views WHERE table_schema = 'webstore'
UNION ALL
SELECT 'liipaisimet', COUNT(*) FROM information_schema.triggers WHERE trigger_schema = 'webstore'
UNION ALL
SELECT 'proseduurit', COUNT(*) FROM information_schema.routines WHERE routine_schema = 'webstore'
UNION ALL
SELECT 'tapahtumat', COUNT(*) FROM information_schema.events WHERE event_schema = 'webstore'
UNION ALL
SELECT 'indeksit (ei PK)', COUNT(DISTINCT table_name, index_name)
  FROM information_schema.statistics WHERE table_schema = 'webstore' AND index_name <> 'PRIMARY'
UNION ALL
SELECT 'roolit', COUNT(*) FROM mysql.user WHERE user LIKE 'webstore\_%\_role'
UNION ALL
SELECT 'käyttäjät', COUNT(*) FROM mysql.user WHERE user IN ('webstore_admin', 'webstore_app', 'webstore_report')
UNION ALL
SELECT 'tuotteita', COUNT(*) FROM products
UNION ALL
SELECT 'tilauksia', COUNT(*) FROM orders
UNION ALL
SELECT 'hintahistoriarivejä', COUNT(*) FROM product_price_history
UNION ALL
SELECT 'myyntikoostepäiviä', COUNT(*) FROM daily_sales_summary;

SELECT @@event_scheduler AS event_scheduler;

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

-- Sovelluskäyttäjän (webstore_app) oikeuksien testi. Ajetaan --force-valitsimella:
-- kielletyt lauseet epäonnistuvat tarkoituksella ja ajo jatkuu.
USE webstore;

SELECT CURRENT_USER() AS kayttaja, CURRENT_ROLE() AS roolit;

-- Sallittu: saldon päivitys (sarakekohtainen UPDATE).
UPDATE products SET stock_quantity = stock_quantity + 1 WHERE id = 8;

-- Kielletty: hinnan suora päivitys -> ERROR 1143.
UPDATE products SET price = 1.00 WHERE id = 8;

-- Kielletty: tilauksen poisto -> ERROR 1142.
DELETE FROM orders WHERE id = 1;

-- Kielletty: tilausrivien massapoisto -> ERROR 1142.
DELETE FROM orderitems WHERE order_id = 1;

-- Proseduurin tarkistukset: liian suuri muutos ja puuttuva syy torjutaan.
CALL change_product_price(8, 99999.00, 'näppäilyvirhe');
CALL change_product_price(8, 10.00, '');

-- Sallittu reitti: hinta muuttuu proseduurilla ja kirjautuu historiaan.
SELECT price INTO @old FROM products WHERE id = 8;
SET @new = ROUND(@old * 1.10, 2);
CALL change_product_price(8, @new, 'hinnankorotus 10 %');
SELECT product_id, price, valid_from, valid_to, change_reason, changed_by
FROM product_price_history WHERE product_id = 8 ORDER BY id;

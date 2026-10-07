-- Hintahistorian testi. Ajetaan sovelluskäyttäjänä (webstore_app), joka voi muuttaa hintaa vain proseduurilla.
USE webstore;

SELECT id, name, price, version FROM products WHERE id = 7;
SELECT price INTO @alkuhinta FROM products WHERE id = 7;

-- -20 % kampanja, paluu normaalihintaan ja +8 % korotus. Välissä tauot, jotta aikaleimat erottuvat.
CALL change_product_price(7, ROUND(@alkuhinta * 0.80, 2), 'kampanja: syysale -20 %');
DO SLEEP(1);
CALL change_product_price(7, @alkuhinta, 'kampanja päättyi');
DO SLEEP(1);
SET @hetki_ennen_korotusta = NOW(6);
DO SLEEP(1);
CALL change_product_price(7, ROUND(@alkuhinta * 1.08, 2), 'toimittajan hinnankorotus +8 %');

SELECT id, name, price, version FROM products WHERE id = 7;

-- Koko historia: jokaisella hinnalla on voimassaoloväli.
SELECT price, valid_from, valid_to, change_reason, changed_by
FROM product_price_history
WHERE product_id = 7
ORDER BY valid_from;

-- Historiallinen haku: mikä hinta oli voimassa annettuna hetkenä?
SELECT @hetki_ennen_korotusta AS ajankohta, price AS voimassa_ollut_hinta
FROM product_price_history
WHERE product_id = 7
  AND valid_from <= @hetki_ennen_korotusta
  AND (valid_to IS NULL OR valid_to > @hetki_ennen_korotusta);

-- Muutokset edelliseen hintaan verrattuna näkymän kautta.
SELECT product_name, previous_price, new_price,
       ROUND((new_price - previous_price) / previous_price * 100, 1) AS muutos_pros,
       changed_at, change_reason
FROM v_product_price_changes
WHERE product_id = 7
ORDER BY changed_at;

-- Skenaario 1: sovellus lukee saldon tavallisella SELECTillä, tarkistaa sen ja kirjoittaa
-- laskemansa uuden arvon. Istunnon nimi (@who) annetaan --init-command-valitsimella.
USE webstore;
START TRANSACTION;

SELECT stock_quantity INTO @stock FROM products WHERE id = 899;
SELECT @who AS istunto, SYSDATE(6) AS aika, @stock AS luettu_saldo,
       @stock >= 2 AS myynti_hyvaksytty, 'luettu' AS vaihe;

-- Sovelluslogiikka: "saldo riittää", 2 kpl myydään. Uusi arvo lasketaan luetusta saldosta.
DO SLEEP(2);
UPDATE products SET stock_quantity = @stock - 2 WHERE id = 899 AND @stock >= 2;
SELECT @who AS istunto, SYSDATE(6) AS aika, 'UPDATE valmis' AS vaihe;

DO SLEEP(2);
COMMIT;
SELECT @who AS istunto, SYSDATE(6) AS aika, 'COMMIT' AS vaihe,
       (SELECT stock_quantity FROM products WHERE id = 899) AS saldo_nyt;

-- Skenaario 2: tarkistus ja vähennys samassa UPDATE-lauseessa. Vain automaattinen rivilukko.
USE webstore;
START TRANSACTION;

SELECT @who AS istunto, SYSDATE(6) AS aika, 'aloitus' AS vaihe;
DO SLEEP(2);
UPDATE products
   SET stock_quantity = stock_quantity - 2
 WHERE id = 899 AND stock_quantity >= 2;
SELECT @who AS istunto, SYSDATE(6) AS aika, ROW_COUNT() AS paivitetty, 'UPDATE valmis' AS vaihe;

DO SLEEP(2);
COMMIT;
SELECT @who AS istunto, SYSDATE(6) AS aika, 'COMMIT' AS vaihe;

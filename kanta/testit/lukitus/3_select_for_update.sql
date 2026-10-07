-- Skenaario 3: sama sovelluslogiikka kuin skenaariossa 1, mutta saldo luetaan eksplisiittisellä
-- SELECT ... FOR UPDATE -lukolla.
USE webstore;
START TRANSACTION;

SELECT @who AS istunto, SYSDATE(6) AS aika, 'aloitus' AS vaihe;
SELECT stock_quantity INTO @stock FROM products WHERE id = 899 FOR UPDATE;
SELECT @who AS istunto, SYSDATE(6) AS aika, @stock AS luettu_saldo,
       @stock >= 2 AS myynti_hyvaksytty, 'luettu FOR UPDATE' AS vaihe;

DO SLEEP(2);
UPDATE products SET stock_quantity = @stock - 2 WHERE id = 899 AND @stock >= 2;
SELECT @who AS istunto, SYSDATE(6) AS aika, 'UPDATE valmis' AS vaihe;

DO SLEEP(2);
COMMIT;
SELECT @who AS istunto, SYSDATE(6) AS aika, 'COMMIT' AS vaihe,
       (SELECT stock_quantity FROM products WHERE id = 899) AS saldo_nyt;

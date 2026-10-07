-- Lähtötilanne jokaiselle skenaariolle: tuotteella 899 on 3 kpl varastossa.
USE webstore;
UPDATE products SET stock_quantity = 3 WHERE id = 899;
SELECT id, name, stock_quantity AS saldo_alussa FROM products WHERE id = 899;

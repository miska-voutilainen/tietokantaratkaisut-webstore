-- Liipaisimien testi: tilamuutosten loki ja varastosaldon suoja. Ajetaan --force-valitsimella,
-- koska viimeinen UPDATE epäonnistuu tarkoituksella.
USE webstore;

-- 1) Uusi tilaus kirjaa alkutilan.
INSERT INTO orders (customer_id, status) VALUES (4242, 'NEW');
SET @order_id = LAST_INSERT_ID();

-- 2) Tilan muutokset kirjautuvat.
UPDATE orders SET status = 'SHIPPED', delivery_date = NOW() WHERE id = @order_id;
-- Sama tila uudelleen ei ole muutos, eikä siitä synny riviä.
UPDATE orders SET status = 'SHIPPED' WHERE id = @order_id;

SELECT order_id, old_status, new_status, changed_at, changed_by
FROM order_status_history
WHERE order_id = @order_id
ORDER BY id;

-- 3) Saldon suoja: tuotteella 1 on rajallinen saldo, joten 100 000 kpl:n vähennys torjutaan.
SELECT id, stock_quantity FROM products WHERE id = 1;
UPDATE products SET stock_quantity = stock_quantity - 100000 WHERE id = 1;
SELECT id, stock_quantity FROM products WHERE id = 1;

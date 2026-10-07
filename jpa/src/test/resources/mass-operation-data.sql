-- Massaoperaatiotestien lähtötilanne. Ajetaan ennen jokaista testiä.
DELETE FROM orderitems;
DELETE FROM order_status_history;
DELETE FROM orders;
DELETE FROM product_price_history;
DELETE FROM products;

INSERT INTO products (id, name, price, stock_quantity, category_id, supplier_id) VALUES
    (101, 'Kuulokkeet',  59.90,   2, 1, 7),
    (102, 'Laturi',      19.90,   5, 1, 7),
    (103, 'Kaapeli',      9.90,  50, 1, 7),
    (104, 'T-paita',     14.90,   1, 2, 8),
    (105, 'Takki',      129.00,   0, 2, 8),
    (106, 'Näyttö',     249.00,  30, 1, 9);

-- Kolme vanhaa käsittelemätöntä, yksi tuore käsittelemätön, yksi vanha toimitettu ja yksi vanha peruttu.
INSERT INTO orders (id, customer_id, order_date, status) VALUES
    (1001, 1, '2024-01-10 10:00:00', 'NEW'),
    (1002, 1, '2024-02-15 12:00:00', 'NEW'),
    (1003, 1, '2024-03-20 09:30:00', 'NEW'),
    (1004, 1, '2025-06-01 08:00:00', 'NEW'),
    (1005, 1, '2024-01-05 16:00:00', 'SHIPPED'),
    (1006, 1, '2024-02-01 11:00:00', 'CANCELLED');

INSERT INTO orderitems (order_id, product_id, quantity, unit_price) VALUES
    (1001, 101, 2,  59.90),
    (1001, 104, 1,  14.90),
    (1002, 102, 3,  19.90),
    (1003, 105, 1, 129.00),
    (1004, 106, 1, 249.00),
    (1005, 103, 4,   9.90),
    (1006, 101, 5,  59.90);

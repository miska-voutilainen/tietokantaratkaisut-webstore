-- V02 Indeksointisuunnitelman indeksit. Perustelut: dokumentaatio/02_indeksointi.md

-- Q1 kirjautuminen sähköpostilla; samalla estetään saman osoitteen kaksoisrekisteröinti.
CREATE UNIQUE INDEX uk_customers_email ON customers (email);

-- Q2 asiakkaan haku nimellä (sukunimi tarkka, etunimen alku).
CREATE INDEX idx_customers_name ON customers (last_name, first_name);

-- Q3 asiakkaan tilaushistoria uusin ensin. Korvaa vierasavaimen yksisarakkeisen indeksin.
CREATE INDEX idx_orders_customer_date ON orders (customer_id, order_date);
DROP INDEX fk_order_customer ON orders;

-- Q8 tilan mukaan suodatettu, päivämäärällä järjestetty tilauslista (simulointitehtävän indeksi).
CREATE INDEX idx_orders_status_order_date ON orders (status, order_date DESC);

-- Q9 aikavälin raportit ja massapäivitykset, jotka rajautuvat tilauspäivään.
CREATE INDEX idx_orders_order_date ON orders (order_date);

-- Q5 tuoteryhmän tuotteet hintajärjestyksessä. Korvaa vierasavaimen indeksin.
CREATE INDEX idx_products_category_price ON products (category_id, price);
DROP INDEX fk_product_category ON products;

-- Q6 tuotehaku nimen alulla.
CREATE INDEX idx_products_name ON products (name);

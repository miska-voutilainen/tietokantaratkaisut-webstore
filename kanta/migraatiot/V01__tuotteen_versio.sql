-- V01 Optimistisen lukituksen versiosarake (JPA @Version). Olemassa olevat rivit saavat version 0.
ALTER TABLE products
    ADD COLUMN version INT NOT NULL DEFAULT 0;

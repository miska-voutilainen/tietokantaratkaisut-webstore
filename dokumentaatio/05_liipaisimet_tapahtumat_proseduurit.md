# Liipaisimet, ajastetut tapahtumat ja proseduurit

Toteutus: `kanta/migraatiot/V03`, `V05`, `V06`, `V07`. Testit `kanta/testit/03_…`, `04_…`, `05_…`,
tulosteet `todennukset/03_liipaisimet.txt`, `04_tapahtuma.txt`, `05_oikeudet_app.txt`.

## 1. Liipaisimet

| Liipaisin | Taulu | Tarkoitus |
|---|---|---|
| `trg_orders_status_log_insert` | `orders` AFTER INSERT | Uuden tilauksen alkutila lokiin |
| `trg_orders_status_log_update` | `orders` AFTER UPDATE | Jokainen tilamuutos lokiin: vanha ja uusi tila, aika, käyttäjä |
| `trg_products_stock_guard` | `products` BEFORE UPDATE | Estää negatiivisen varastosaldon |
| `trg_products_price_history_insert/update` | `products` | Hintahistoria (ks. [06](06_historiatiedot.md)) |

**Miksi tilaloki on liipaisin eikä sovelluskoodia:** tilaa muuttavat REST-API, JPA:n massapäivitys
(`cancel-stale`), ylläpitäjän SQL-työkalu ja tulevaisuudessa muut järjestelmät. Liipaisin kirjaa ne
kaikki eikä sitä voi unohtaa. Asiakaspalvelu näkee, milloin ja kuka tilauksen perui, ja lokista voi
laskea esim. toimitusajat. `changed_by` käyttää `USER()`-funktiota, joten lokiin tallentuu todellinen
kirjautunut käyttäjä eikä liipaisimen omistaja.

```sql
CREATE TRIGGER trg_orders_status_log_update
AFTER UPDATE ON orders
FOR EACH ROW
BEGIN
    IF NOT (NEW.status <=> OLD.status) THEN
        INSERT INTO order_status_history (order_id, old_status, new_status, changed_at, changed_by)
        VALUES (NEW.id, OLD.status, NEW.status, NOW(6), USER());
    END IF;
END
```

**Saldosuoja** on viimeinen puolustuslinja. JPA:n `@PreUpdate`-tarkistus ei koske JPQL-massapäivityksiä
eikä suoraa SQL:ää, mutta tietokannan liipaisin koskee.

### Testi

```sql
INSERT INTO orders (customer_id, status) VALUES (4242, 'NEW');
UPDATE orders SET status = 'SHIPPED', delivery_date = NOW() WHERE id = @order_id;
UPDATE orders SET status = 'SHIPPED' WHERE id = @order_id;   -- ei muutosta, ei lokiriviä
```

| order_id | old_status | new_status | changed_at | changed_by |
|---|---|---|---|---|
| 200001 | NULL | NEW | 2026-10-07 15:54:03.837622 | webstore_admin@localhost |
| 200001 | NEW | SHIPPED | 2026-10-07 15:54:03.842608 | webstore_admin@localhost |

`UPDATE products SET stock_quantity = stock_quantity - 100000 WHERE id = 1` →
`ERROR 1644 (45000): Varastosaldo ei voi olla negatiivinen`, ja saldo pysyi 136:ssa.

Massatilanteessa liipaisin toimii riveittäin: JPQL-massaperuminen 4 899 tilaukselle tuotti 4 899
lokiriviä (`todennukset/10_jpa_testit.txt`).

## 2. Ajastetut tapahtumat

| Tapahtuma | Aikataulu | Tarkoitus |
|---|---|---|
| `ev_refresh_daily_sales` | Joka yö klo 02.00 | Laskee `daily_sales_summary`-koosteen uudelleen viimeiseltä 7 päivältä (peruutukset voivat muuttaa mennyttä) |
| `ev_purge_old_logs` | Kuun 1. päivä klo 03.00 | Poistaa yli 3 vuotta vanhat tilaloki- ja ajolokirivit |

Myyntiraportti summaisi muuten 1,1 miljoonaa tilausriviä joka kerta (2,8 s, ks. indeksoinnin Q13).
Koostetaulusta sama tieto luetaan 731 rivistä. Jokainen ajo kirjaa `event_run_log`-tauluun alun,
lopun ja rivimäärän, joten epäonnistunut tai väliin jäänyt ajo huomataan.

```sql
CREATE EVENT ev_refresh_daily_sales
ON SCHEDULE EVERY 1 DAY
STARTS (CURRENT_DATE + INTERVAL 1 DAY + INTERVAL 2 HOUR)
ON COMPLETION PRESERVE
COMMENT 'Päivittäisen myyntikoosteen päivitys'
DO
BEGIN
    DECLARE v_started DATETIME(6) DEFAULT NOW(6);
    CALL refresh_daily_sales(CURRENT_DATE - INTERVAL 7 DAY);
    INSERT INTO event_run_log (event_name, started_at, finished_at, rows_affected)
    SELECT 'ev_refresh_daily_sales', v_started, NOW(6), COUNT(*)
    FROM daily_sales_summary
    WHERE sales_date >= CURRENT_DATE - INTERVAL 7 DAY;
END
```

### Testi

Tänään tehty tilaus lisättiin, ja tapahtuma ajastettiin hetkeksi käynnistymään 3 s päästä
(`ALTER EVENT … STARTS CURRENT_TIMESTAMP + INTERVAL 3 SECOND`). Lopuksi palautettiin yöaikataulu.

| Vaihe | Tulos |
|---|---|
| Ennen | Tämän päivän koosteriviä ei ole, ajolokissa 0 ajoa |
| Jälkeen | `2026-10-07 | order_count 2 | item_count 2 | revenue 1699.32` |
| `event_run_log` | `ev_refresh_daily_sales`, 15:54:06.930862 → 15:54:06.933772, 1 rivi |
| `information_schema.events` | `LAST_EXECUTED 2026-10-07 15:54:06`, palautettu `STARTS 2026-10-08 02:00:00` |

Tapahtuman muuttaminen vaatii tapahtuman omistajan (root) oikeudet, joten testi ajetaan asennustilillä.

## 3. Tallennetut proseduurit (vapaaehtoinen)

**Tilanne:** tuotteen hinta on liiketoiminnan kannalta herkin tieto. Väärä näppäily (99999 €) tai
virheellinen massapäivitys menisi suoraan kauppaan, ja ilman syytä muutoksia ei voi jäljittää.
Siksi sovelluskäyttäjältä on poistettu `price`-sarakkeen UPDATE-oikeus (V08:
`REVOKE UPDATE … ; GRANT UPDATE (name, description, stock_quantity, …)`). Hinta muuttuu vain
proseduurilla, joka
- tarkistaa, että hinta on positiivinen ja muutos enintään ±50 %,
- vaatii syyn ja kirjaa sen hintahistoriaan,
- lukitsee rivin (`FOR UPDATE`) ja kasvattaa versiota, jotta JPA:n optimistinen lukitus huomaa muutoksen,
- ajetaan omistajan oikeuksin (`SQL SECURITY DEFINER`), joten kutsujalle riittää `EXECUTE`.

```sql
CREATE PROCEDURE change_product_price(
    IN p_product_id INT, IN p_new_price DECIMAL(10,2), IN p_reason VARCHAR(255))
SQL SECURITY DEFINER
BEGIN
    DECLARE v_old_price DECIMAL(10,2) DEFAULT NULL;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @price_change_reason = NULL;
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_new_price IS NULL OR p_new_price <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Hinnan on oltava positiivinen';
    END IF;
    IF p_reason IS NULL OR TRIM(p_reason) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Hinnanmuutokselle on annettava syy';
    END IF;

    START TRANSACTION;
    SELECT price INTO v_old_price FROM products WHERE id = p_product_id FOR UPDATE;
    IF v_old_price IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tuotetta ei löydy';
    END IF;
    IF p_new_price > v_old_price * 1.5 OR p_new_price < v_old_price * 0.5 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Hinta saa muuttua kerralla enintään 50 %';
    END IF;

    SET @price_change_reason = p_reason;
    UPDATE products SET price = p_new_price, version = version + 1 WHERE id = p_product_id;
    SET @price_change_reason = NULL;
    COMMIT;
END
```

### Käyttö sovelluskäyttäjänä (`05_oikeudet_app.txt`)

| Lause | Tulos |
|---|---|
| `UPDATE products SET price = 1.00 WHERE id = 8` | `ERROR 1143: UPDATE command denied … for column 'price'` |
| `CALL change_product_price(8, 99999.00, 'näppäilyvirhe')` | `ERROR 1644: Hinta saa muuttua kerralla enintään 50 %` |
| `CALL change_product_price(8, 10.00, '')` | `ERROR 1644: Hinnanmuutokselle on annettava syy` |
| `CALL change_product_price(8, @old * 1.10, 'hinnankorotus 10 %')` | OK, historiaan rivi `webstore_app@localhost` |

Sovellus kutsuu proseduuria Spring Datan `@Procedure`-annotaatiolla (`PUT /api/products/{id}/price`),
ja proseduurin virheet palautuvat käyttäjälle HTTP 400 -vastauksina (`09_api_demo.txt`).

**Hyödyt:** hinnan eheyssäännöt ovat yhdessä paikassa tietokannassa, eikä niitä voi ohittaa
sovelluksesta, SQL-työkalusta tai murretulla sovellustunnuksella. Jokaisella hinnanmuutoksella on syy ja
tekijä.

Toinen proseduuri `place_order_transaction` on transaktiotehtävästä: se tekee tilauksen ja saldon
vähennyksen yhtenä transaktiona ja peruu kaiken virheessä.

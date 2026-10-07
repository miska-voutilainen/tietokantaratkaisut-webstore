# Historiatiedot (temporaalisuus)

Toteutus: `kanta/migraatiot/V03__hintahistoria.sql`. Testi: `kanta/testit/02_hintahistoria_testi.sql`,
tuloste `todennukset/02_hintahistoria.txt`.

## Mitä kannattaa säilyttää historiana

| Tieto | Miksi |
|---|---|
| **Tuotteen hinta** (toteutettu) | Kampanjoiden vaikutus myyntiin, hinnoittelun seuranta, asiakkaan reklamaatio ("hinta oli eilen halvempi"), kirjanpito ja kuluttajansuoja (alennusta verrataan 30 päivän alimpaan hintaan) |
| **Tilauksen tila** (toteutettu liipaisintehtävässä, `order_status_history`) | Toimitusajat, peruutusten syyt ja ajankohdat, asiakaspalvelun selvitykset |
| Varastosaldo | Hävikki, menekin ennustaminen, inventaariopoikkeamat |
| Asiakkaan osoite | Mihin osoitteeseen vanha tilaus toimitettiin, vaikka asiakas on muuttanut |

Tilausrivillä on jo oma `unit_price`, joten vanhan tilauksen summa ei muutu hinnan muuttuessa.
Tuotteen nykyinen hinta kuitenkin ylikirjoittuu, ja ilman historiaa ei tiedetä, mikä hinta oli voimassa
milloinkin.

## Ratkaisu: voimassaoloväli

```sql
CREATE TABLE product_price_history (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    valid_from DATETIME(6) NOT NULL,
    valid_to DATETIME(6) NULL,            -- NULL = nykyinen hinta
    change_reason VARCHAR(255) NULL,
    changed_by VARCHAR(288) NOT NULL,
    CONSTRAINT fk_price_history_product FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE,
    INDEX idx_price_history_product_time (product_id, valid_from, valid_to)
);
```

- Jokainen hinta on voimassa puoliavoimella välillä `[valid_from, valid_to)`. Edellisen rivin
  `valid_to` on sama aikaleima kuin seuraavan `valid_from`, joten välit eivät mene päällekkäin eikä
  niiden väliin jää aukkoa.
- **AFTER UPDATE -liipaisin** sulkee avoimen rivin ja avaa uuden aina, kun `price` muuttuu, teki
  muutoksen sitten proseduuri, ylläpitäjä tai mikä tahansa muu. AFTER INSERT avaa rivin uudelle tuotteelle.
- Asennus tallentaa kaikkien 1 000 tuotteen nykyisen hinnan ensimmäiseksi riviksi. Aiempaa hintatietoa
  aineistossa ei ole.
- Syy tulee `change_product_price`-proseduurin asettamasta istuntomuuttujasta; suora UPDATE kirjautuu
  syyllä "suora UPDATE".
- `DATETIME(6)` (mikrosekunnit), jotta saman sekunnin muutokset järjestyvät oikein.

## Testi: päivitykset ja tallentunut historia

Tuotteen 7 hintaa muutettiin sovelluskäyttäjänä kolme kertaa sekunnin välein: −20 % kampanja,
paluu normaalihintaan ja +8 % korotus. Ennen viimeistä muutosta otettiin talteen aikaleima
`@hetki_ennen_korotusta`.

| price | valid_from | valid_to | change_reason | changed_by |
|---|---|---|---|---|
| 352.35 | 2026-10-07 15:53:56.467538 | 2026-10-07 15:54:00.739885 | alkuarvo asennuksessa | root@localhost |
| 281.88 | 2026-10-07 15:54:00.739885 | 2026-10-07 15:54:01.747161 | kampanja: syysale -20 % | webstore_app@localhost |
| 352.35 | 2026-10-07 15:54:01.747161 | 2026-10-07 15:54:03.767794 | kampanja päättyi | webstore_app@localhost |
| 380.54 | 2026-10-07 15:54:03.767794 | NULL | toimittajan hinnankorotus +8 % | webstore_app@localhost |

Tuotteen nykyinen hinta on 380.54, ja versio on 3.

## SQL-kyselyt historiaan

**Hinta tiettynä hetkenä:**

```sql
SELECT price AS voimassa_ollut_hinta
FROM product_price_history
WHERE product_id = 7
  AND valid_from <= @hetki_ennen_korotusta
  AND (valid_to IS NULL OR valid_to > @hetki_ennen_korotusta);
```

| ajankohta | voimassa_ollut_hinta |
|---|---|
| 2026-10-07 15:54:02.752434 | 352.35 |

**Muutokset edelliseen hintaan verrattuna** (näkymä `v_product_price_changes`, `LAG`-ikkunafunktio):

```sql
SELECT product_name, previous_price, new_price,
       ROUND((new_price - previous_price) / previous_price * 100, 1) AS muutos_pros,
       changed_at, change_reason
FROM v_product_price_changes
WHERE product_id = 7
ORDER BY changed_at;
```

| previous_price | new_price | muutos_pros | change_reason |
|---|---|---|---|
| NULL | 352.35 | NULL | alkuarvo asennuksessa |
| 352.35 | 281.88 | -20.0 | kampanja: syysale -20 % |
| 281.88 | 352.35 | 25.0 | kampanja päättyi |
| 352.35 | 380.54 | 8.0 | toimittajan hinnankorotus +8 % |

**Alin hinta 30 päivän ajalta** (alennusmerkinnän vertailuhinta):

```sql
SELECT MIN(price)
FROM product_price_history
WHERE product_id = 7
  AND valid_from < NOW()
  AND (valid_to IS NULL OR valid_to > NOW() - INTERVAL 30 DAY);
```

Sama temporaalinen haku on sovelluksessa: `GET /api/products/{id}/price-at?at=…` ja
`GET /api/products/{id}/price-history` (`09_api_demo.txt`).

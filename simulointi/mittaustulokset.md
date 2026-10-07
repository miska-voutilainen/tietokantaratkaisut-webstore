# mysqlslap-mittaustulokset 26.8.2026

## Ympäristö

- MySQL 8.0.46, paikallinen TCP-yhteys 127.0.0.1:3306
- Skeema: webstore
- Aineisto: 100 000 customers, 200 000 orders, 1 099 773 orderitems, 1 000 products
- Palvelimen `max_connections`: 151
- Simulaattori: mysqlslap 8.0.46

## Vakiokuorma

- concurrency: 20
- iterations: 5
- number-of-queries: 100 per iteraatio
- keskimäärin 5 kyselyä per asiakas
- lämmittely: 20 kyselyä, yksi per asiakas; ei mukana ajoissa
- kyselyt suoritettiin erillisistä kommentittomista SQL-tiedostoista

| Kysely | Keskimääräinen erä (s) | Min (s) | Max (s) | Arvio / kysely (ms) |
|---|---:|---:|---:|---:|
| Q1 Vähissä olevat tuotteet | 0,021 | 0,015 | 0,031 | 4,2 |
| Q2 Tilausrivit ja tuotetiedot | 0,018 | 0,015 | 0,031 | 3,6 |
| Q3 Asiakkaat ilman tilauksia | 0,025 | 0,016 | 0,031 | 5,0 |
| Q4 Tuoteryhmien hintakooste | 0,100 | 0,094 | 0,109 | 20,0 |
| Q5 Keskihintaa kalliimmat tuotteet | 0,022 | 0,016 | 0,031 | 4,4 |
| Q6 Lähetetyt tilaukset päivämäärällä, ennen indeksiä | 1,206 | 0,594 | 1,593 | 241,2 |

Asiakaskohtainen vastearvio = mysqlslapin keskimääräinen eräaika / 5, koska kukin 20 asiakkaasta suoritti keskimäärin viisi kyselyä per iteraatio.

## Optimointi

```sql
CREATE INDEX idx_orders_status_order_date
    ON orders (status, order_date DESC);
```

- Ennen indeksiä `EXPLAIN ANALYZE`: `Table scan on orders`, 200 000 riviä, noin 105 ms yksittäisajossa.
- Indeksin jälkeen: `Index range scan ... idx_orders_status_order_date`, LIMIT 50 saavutettiin noin 1,88 ms:ssa yksittäisajossa.
- Reilu mysqlslap-vertailu tehtiin samalla valmiiksi lämmitetyllä aineistolla muuttamalla indeksi vuorotellen näkymättömäksi ja näkyväksi.

| Q6 | Keskimääräinen erä (s) | Min (s) | Max (s) | Arvio / kysely (ms) |
|---|---:|---:|---:|---:|
| Indeksi näkymätön | 1,206 | 0,594 | 1,593 | 241,2 |
| Indeksi näkyvä | 0,040 | 0,031 | 0,047 | 8,0 |

Keskimääräinen eräaika lyheni 96,7 prosenttia ja suoritus nopeutui noin 30,2-kertaiseksi.

## Skaalausvaran testi

- concurrency: 40
- iterations: 5
- number-of-queries: 200, eli edelleen 5 kyselyä per asiakas
- Q6 indeksin kanssa: keskimääräinen erä 0,109 s, min 0,109 s, max 0,110 s
- asiakaskohtainen vastearvio: 21,8 ms

# Indeksointi

Kyselyt: `kanta/testit/indeksointi_kyselyt.sql`. Indeksit: `kanta/migraatiot/V02__indeksit.sql`.
Suunnitelmat on ajettu `EXPLAIN ANALYZE`-komennolla populoidussa kannassa (100 000 asiakasta,
200 000 tilausta, 1,1 miljoonaa tilausriviä, 1 000 tuotetta). Tulosteet:
`todennukset/01_indeksit_ennen.txt` (vain perusskeeman indeksit) ja `todennukset/01_indeksit_jalkeen.txt`.

Lähtötilanteessa kannassa on vain pääavaimet ja vierasavainten automaattiset indeksit.

## Kyselyt, suunnitelmat ja päätökset

| # | Mitä kysely palauttaa | Ennen | Päätös | Jälkeen |
|---|---|---|---|---|
| Q1 | Asiakas sähköpostilla (kirjautuminen) | Table scan 100 000 riviä, 20,8 ms | **UNIQUE `uk_customers_email (email)`** | Vakiohaku, < 0,001 ms |
| Q2 | Asiakkaat sukunimellä ja etunimen alulla | Table scan + sort, 22,5 ms | **`idx_customers_name (last_name, first_name)`** | Index range scan 79 riviä, 0,26 ms |
| Q3 | Asiakkaan 20 viimeisintä tilausta | FK-indeksi + erillinen lajittelu, 0,14 ms | **`idx_orders_customer_date (customer_id, order_date)`**, korvaa `fk_order_customer` | Indeksi luetaan takaperin, ei lajittelua, 0,10 ms |
| Q4 | Tilauksen rivit tuotetietoineen | PK-haut, 0,04 ms | Ei uutta: `orderitems`-PK alkaa `order_id`:llä | – |
| Q5 | Tuoteryhmän 20 halvinta | FK-indeksi + sort 116 riviä, 0,20 ms | **`idx_products_category_price (category_id, price)`**, korvaa `fk_product_category` | Lukee vain 20 riviä valmiissa järjestyksessä, 0,04 ms |
| Q6 | Tuotteet nimen alulla `LIKE 'Quantum%'` | Table scan 1 000 riviä, 0,19 ms | **`idx_products_name (name)`** | Index range scan 21 riviä, 0,04 ms |
| Q7 | Vähissä olevat tuotteet `stock_quantity < 10` | Table scan 1 000 riviä, 0,20 ms | Ei indeksiä | – |
| Q8 | 50 uusinta `NEW`-tilausta | Table scan 200 000 + sort, 44,1 ms | **`idx_orders_status_order_date (status, order_date DESC)`** | Index lookup, 50 riviä, 1,37 ms |
| Q9 | Tammikuun 2025 tilausmäärä | Table scan 200 000, 29 ms | **`idx_orders_order_date (order_date)`** | Covering index range scan 8 453 riviä, 1,69 ms |
| Q10 | Tuotteen myyntirivit | FK-indeksi, 3 ms | Ei uutta | – |
| Q11 | Asiakkaan osoitteet | FK-indeksi, 0,01 ms | Ei uutta | – |
| Q12 | Toimittajan tuotteet | FK-indeksi, 0,11 ms | Ei uutta | – |
| Q13 | 10 myydyintä tuotetta | Koko `orderitems` (1,1 M), 2,8 s | Ei indeksiä, vaan koostetaulu (ks. alla) | – |

## Perustelut

- **Q1 ja Q2** ovat verkkokaupan yleisimpiä hakuja. Ilman indeksiä jokainen kirjautuminen luki koko
  asiakastaulun. Sähköpostin UNIQUE-indeksi myös estää saman osoitteen kaksoisrekisteröinnin.
- **Yhdistelmäindeksit (Q3, Q5, Q8)** palvelevat sekä suodatusta että järjestystä. Ensimmäinen sarake
  rajaa, toinen antaa valmiin järjestyksen, joten `ORDER BY … LIMIT` loppuu heti. Koska Q3:n ja Q5:n
  indeksit alkavat vierasavaimen sarakkeella, ne kelpaavat myös vierasavaimen indeksiksi, ja vanhat
  yksisarakkeiset FK-indeksit poistetaan. Näin päällekkäinen indeksi ei hidasta kirjoituksia.
- **Q9:n** aikaväliraportit ja massapäivitys `cancel-stale` rajautuvat tilauspäivään. Indeksi on
  kattava (covering), koska `COUNT(*)` ei tarvitse muita sarakkeita.
- **Q7:lle ei tehdä indeksiä.** Taulussa on vain 1 000 riviä, joiden läpikäynti kestää 0,2 ms, ja
  `stock_quantity` muuttuu jokaisessa tilauksessa. Indeksi hidastaisi tärkeintä kirjoitusta
  saavuttamatta lukemisessa mitään.
- **Q13:lle ei tehdä indeksiä.** Raportti summaa kaikki 1,1 miljoonaa riviä, joten indeksikään ei
  vähennä luettavien rivien määrää. Ratkaisu on `daily_sales_summary`-koostetaulu, jonka ajastettu
  tapahtuma päivittää yöllä (V07), ja raportit lukevat sitä.
- **Q4, Q10–Q12** käyttävät jo pääavainta tai vierasavaimen indeksiä.

## Kustannukset

Jokainen indeksi hidastaa INSERT/UPDATE-lauseita ja vie levytilaa. Indeksit on rajattu kyselyihin, jotka
ajetaan usein tai jotka muuten lukisivat koko suuren taulun. Indeksien vaikutus kuormitettuna mitataan
myöhemmin suorituskykysimulaatiossa (vrt. `simulointi/mittaustulokset.md`, jossa Q8:n indeksi nopeutti
20 rinnakkaisen asiakkaan kuormaa noin 30-kertaisesti).

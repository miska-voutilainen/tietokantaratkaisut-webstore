# Webstore – yhdistetty projektitietokanta

Verkkokaupan MySQL 8 -tietokanta ja sen päällä toimiva Spring Boot / JPA -backend. Kaikki
kurssitehtävien osat (indeksit, lukitus, näkymät, liipaisimet, ajastetut tapahtumat, proseduurit,
historiatiedot, käyttäjät ja roolit, API ja massaoperaatiot) asentuvat yhteen `webstore`-kantaan
yhdellä skriptillä.

## Rakenne

| Polku | Sisältö |
|---|---|
| `schema_populated_dump.sql`, `schema_no_data_dump.sql` | Perusskeema ja testidata (lähtöaineisto) |
| `kanta/migraatiot/V01…V08` | Kaikki skeemamuutokset järjestyksessä |
| `kanta/webstore_migraatiot.sql` | Migraatiot koottuna yhdeksi tiedostoksi (generoitu) |
| `kanta/asenna.ps1` | Rakentaa koko kannan: dump + migraatiot + tarkistus |
| `kanta/aja_testit.ps1` | Ajaa SQL-todennukset oikeilla käyttäjillä |
| `kanta/testit/` | Todennus-SQL:t (indeksit, historia, liipaisimet, tapahtuma, oikeudet, näkymät, lukitus) |
| `jpa/` | Spring Boot -sovellus: entiteetit, repositoriot, palvelut, REST-API, testit |
| `jpa/api_demo.ps1` | API:n pääpolkujen ajo käynnissä olevaa sovellusta vasten |
| `dokumentaatio/` | Suunnitelmat ja perustelut aiheittain |
| `dokumentaatio/todennukset/` | Ajettujen testien tulosteet |
| `transaktiot/`, `simulointi/`, `jpa/sql/` | Aiempien tehtävien alkuperäiset tiedostot (sisältö mukana migraatioissa V01, V02 ja V06) |

## Migraatiot

| Versio | Sisältö | Dokumentaatio |
|---|---|---|
| V01 | `products.version` optimistiseen lukitukseen | [08](dokumentaatio/08_massaoperaatiot.md) |
| V02 | Indeksit | [02](dokumentaatio/02_indeksointi.md) |
| V03 | Hintahistoria (`product_price_history`) ja sen liipaisimet | [06](dokumentaatio/06_historiatiedot.md) |
| V04 | Näkymät `v_product_catalog`, `v_order_summary`, `v_product_price_changes` | [04](dokumentaatio/04_nakymat.md) |
| V05 | Tilaloki (`order_status_history`) ja saldosuoja -liipaisimet | [05](dokumentaatio/05_liipaisimet_tapahtumat_proseduurit.md) |
| V06 | Proseduurit `place_order_transaction`, `change_product_price` | [05](dokumentaatio/05_liipaisimet_tapahtumat_proseduurit.md) |
| V07 | Myyntikooste, ajastetut tapahtumat, `v_monthly_sales` | [05](dokumentaatio/05_liipaisimet_tapahtumat_proseduurit.md) |
| V08 | Roolit ja käyttäjät | [07](dokumentaatio/07_kayttajat_varmuuskopiointi_skeemamuutokset.md) |

## Asennus

Vaatii MySQL 8.0:n (`event_scheduler = ON`, oletus), Java 17+ ja Mavenin.

```powershell
# HUOM: poistaa olemassa olevan webstore-skeeman ja rakentaa sen uudelleen dumpista.
.\kanta\asenna.ps1 -RootPassword '<root-salasana>'                # populoitu data (~1 min)
.\kanta\asenna.ps1 -RootPassword '<root-salasana>' -Data tyhja    # tyhjä kanta

# Todennukset -> dokumentaatio\todennukset
.\kanta\aja_testit.ps1 -RootPassword '<root-salasana>'
```

Käyttäjien salasanat annetaan parametreilla `-AdminPassword`, `-AppPassword` ja `-ReportPassword`.
Oletukset ovat vain paikallista kehitystä varten.

## Sovellus

```powershell
cd jpa
mvn test                       # 23 testiä H2-kannassa
mvn spring-boot:run            # http://localhost:8080, kirjautuu käyttäjänä webstore_app
.\api_demo.ps1                 # toisessa ikkunassa

# Integraatiotestit oikeaa kantaa vasten (muuttavat dataa, aja testikannassa)
$env:WEBSTORE_MYSQL_URL = 'jdbc:mysql://127.0.0.1:3306/webstore'
$env:WEBSTORE_MYSQL_PASSWORD = 'App_vaihda_2026!'
mvn test
```

Sovelluksen kantasalasana annetaan ympäristömuuttujalla `WEBSTORE_DB_PASSWORD`.

## Dokumentaatio

1. [API-spesifikaatio ja entiteetit](dokumentaatio/01_api-spesifikaatio.md)
2. [Indeksointi](dokumentaatio/02_indeksointi.md)
3. [Lukitus ja samanaikaisuus](dokumentaatio/03_lukitus.md)
4. [Näkymät](dokumentaatio/04_nakymat.md)
5. [Liipaisimet, ajastetut tapahtumat ja proseduurit](dokumentaatio/05_liipaisimet_tapahtumat_proseduurit.md)
6. [Historiatiedot](dokumentaatio/06_historiatiedot.md)
7. [Käyttäjät, varmuuskopiointi ja skeemamuutokset](dokumentaatio/07_kayttajat_varmuuskopiointi_skeemamuutokset.md)
8. [Massaoperaatiot](dokumentaatio/08_massaoperaatiot.md)

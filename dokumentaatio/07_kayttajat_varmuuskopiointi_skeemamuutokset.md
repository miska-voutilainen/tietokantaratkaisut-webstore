# Käyttäjät ja roolit, varmuuskopiointi ja skeemamuutokset

## 1. Roolit ja käyttäjät

Toteutus: `kanta/migraatiot/V08__kayttajat_ja_roolit.sql`. Testit: `todennukset/05_oikeudet_app.txt`
ja `06_oikeudet_raportointi.txt`.

Oikeudet annetaan rooleille, ja käyttäjät saavat roolin. Uusi kehittäjä tai raportointityökalu saa
yhdellä `GRANT rooli TO käyttäjä` -lauseella täsmälleen oikeat oikeudet.

| Rooli / käyttäjä | Kuka | Oikeudet | Perustelu |
|---|---|---|---|
| `webstore_admin_role` / `webstore_admin` | Tietokannan ylläpitäjä | `ALL PRIVILEGES ON webstore.*` | Skeemamuutokset, näkymät, liipaisimet, tapahtumat, datan korjaukset. Ei palvelintason oikeuksia eikä muita kantoja. |
| `webstore_app_role` / `webstore_app` | Spring Boot -backend | Taulukohtaiset SELECT/INSERT/UPDATE/DELETE vain API:n tarvitsemiin tauluihin, **sarakekohtainen** UPDATE `products`- ja `orders`-tauluihin, EXECUTE kahteen proseduuriin | Pienin tarvittava oikeus: murrettu sovellus ei voi pudottaa tauluja, poistaa tilauksia, muuttaa hintoja ohi proseduurin eikä väärentää historiaa. |
| `webstore_report_role` / `webstore_report` | Raportointi / BI | Vain SELECT neljään näkymään ja koostetauluun | Ei pääsyä henkilötietoihin (sähköposti, puhelin) eikä mitään kirjoitusoikeutta. |
| `root` | Asennus ja palvelimen hallinta | Kaikki | Vain asennukseen ja varmuuskopiointiin. Omistaa liipaisimet, proseduurit ja tapahtumat (DEFINER). |

### Keskeiset lauseet

```sql
CREATE ROLE 'webstore_admin_role', 'webstore_app_role', 'webstore_report_role';

GRANT ALL PRIVILEGES ON webstore.* TO 'webstore_admin_role';

GRANT SELECT, INSERT, UPDATE, DELETE ON webstore.customers TO 'webstore_app_role';
GRANT SELECT, INSERT ON webstore.orderitems TO 'webstore_app_role';
-- Tilauksia ei poisteta vaan ne perutaan: ei DELETE-oikeutta, ja vain kolme saraketta on päivitettävissä.
GRANT SELECT, INSERT, UPDATE (status, delivery_date, shipping_address_id) ON webstore.orders TO 'webstore_app_role';
GRANT EXECUTE ON PROCEDURE webstore.change_product_price TO 'webstore_app_role';

-- Hinnan suora päivitys poistetaan ja korvataan sarakekohtaisella oikeudella ilman price-saraketta.
GRANT SELECT, INSERT, UPDATE, DELETE ON webstore.products TO 'webstore_app_role';
REVOKE UPDATE ON webstore.products FROM 'webstore_app_role';
GRANT UPDATE (name, description, stock_quantity, category_id, supplier_id, version)
    ON webstore.products TO 'webstore_app_role';

GRANT SELECT ON webstore.v_order_summary TO 'webstore_report_role';
GRANT SELECT ON webstore.v_monthly_sales TO 'webstore_report_role';

CREATE USER 'webstore_app'@'localhost' IDENTIFIED BY '…';
GRANT 'webstore_app_role' TO 'webstore_app'@'localhost';
SET DEFAULT ROLE ALL TO 'webstore_app'@'localhost';
```

Muita REVOKE-käyttötapauksia: rooli poistetaan työntekijän lähtiessä
(`REVOKE 'webstore_admin_role' FROM 'matti'@'localhost'`), ja väliaikainen korjausoikeus perutaan
korjauksen jälkeen (`REVOKE DELETE ON webstore.orderitems FROM …`).

### Testitulokset

| Käyttäjä | Lause | Tulos |
|---|---|---|
| webstore_app | `UPDATE products SET stock_quantity = … ` | OK |
| webstore_app | `UPDATE products SET price = 1.00` | ERROR 1143 (sarakkeeseen ei oikeutta) |
| webstore_app | `DELETE FROM orders WHERE id = 1` | ERROR 1142 |
| webstore_app | `DELETE FROM orderitems …` | ERROR 1142 |
| webstore_report | `SELECT * FROM v_monthly_sales` | OK |
| webstore_report | `SELECT email, phone FROM customers` | ERROR 1142 |
| webstore_report | `UPDATE daily_sales_summary …` | ERROR 1142 |

Spring Boot -sovellus kirjautuu käyttäjänä `webstore_app`, ja kaikki 29 JPA-testiä sekä API-demo
toimivat näillä oikeuksilla. Siksi `Product`- ja `Order`-entiteeteissä on `@DynamicUpdate`: Hibernate
lähettää vain muuttuneet sarakkeet eikä yritä kirjoittaa sarakkeisiin, joihin oikeutta ei ole.

## 2. Varmuuskopiointisuunnitelma

| Mitä | Milloin | Miten | Minne | Kuka |
|---|---|---|---|---|
| Täysi looginen varmuuskopio | Joka yö klo 01.00 (ennen klo 02 koosteajoa) | `mysqldump --single-transaction --routines --triggers --events --set-gtid-purged=OFF webstore`, pakattuna | Varmuuskopiopalvelimen levy + kopio pilvitallennukseen (eri sijainti) | Ajastettu tehtävä (Windows Task Scheduler / cron), vastuu ylläpitäjällä |
| Binäärilokit (muutokset varmuuskopioiden välissä) | Jatkuvasti, kopio 15 min välein | `binlog_expire_logs_seconds` = 8 vrk, `mysqlbinlog --read-from-remote-server --raw` | Varmuuskopiopalvelin | Ylläpitäjä |
| Käyttäjät ja oikeudet | Joka yö | Sisältyy V08-migraatioon (versionhallinnassa); lisäksi `SHOW GRANTS` -tuloste | Versionhallinta | Ylläpitäjä |
| Ennen jokaista skeemamuutosta | Ad hoc | Sama mysqldump | Varmuuskopiopalvelin | Muutoksen tekijä |

`--single-transaction` ottaa InnoDB-tauluista yhtenäisen tilannekuvan lukitsematta kauppaa.
`--routines --triggers --events` ovat välttämättömiä, koska muuten proseduurit, liipaisimet ja
ajastetut tapahtumat eivät tulisi mukaan.

**Säilytys:** päivittäiset 14 vrk, viikoittaiset (sunnuntai) 8 viikkoa, kuukausittaiset 12 kk.
Varmuuskopiot salataan, koska ne sisältävät asiakkaiden henkilötietoja.

**Tavoitteet:** RPO enintään 15 min (yövarmuuskopio + binäärilokit), RTO noin 1 h.

**Palautus:**
1. Pysäytä sovellus (tai ohjaa huoltosivulle), ettei uusia tilauksia kirjoiteta.
2. Palauta viimeisin yövarmuuskopio: `mysql webstore < webstore_YYYYMMDD.sql`.
3. Aja binäärilokit varmuuskopion hetkestä virhettä edeltävään hetkeen:
   `mysqlbinlog --start-datetime=… --stop-datetime=… binlog.* | mysql`.
4. Tarkista `kanta/testit/00_asennuksen_tarkistus.sql`-kyselyllä, että taulut, näkymät, liipaisimet,
   proseduurit, tapahtumat ja rivimäärät ovat paikallaan, ja `SHOW EVENTS`, että tapahtumat ovat ENABLED.
5. Käynnistä sovellus ja aja savutesti (`api_demo.ps1`:n GET-kutsut).

**Palautusvalmiuden testaus:** kerran kuukaudessa viimeisin varmuuskopio palautetaan erilliseen
testi-instanssiin, verrataan rivimäärät tuotantoon ja ajetaan `mvn test` integraatiotesteineen sitä
vastaan. Palautukseen kulunut aika kirjataan, ja se on RTO:n todellinen mittari. Varmuuskopio, jota ei
ole koskaan palautettu, ei ole todistetusti varmuuskopio. Varmuuskopiotehtävä hälyttää, jos tiedostoa
ei synny tai se on edellistä selvästi pienempi.

## 3. Skeemamuutosten toimintasuunnitelma

Esimerkki: `products`-tauluun lisätään sarake `weight_grams INT NULL`.

1. **Migraatio versionhallintaan.** Muutos kirjoitetaan uudeksi numeroiduksi tiedostoksi
   (`kanta/migraatiot/V09__tuotteen_paino.sql`), eikä vanhoja migraatioita muokata. Tuotannossa
   käytettäisiin migraatiotyökalua (Flyway/Liquibase), joka pitää kirjaa ajetuista versioista ja ajaa
   jokaisen vain kerran.
2. **Taaksepäin yhteensopiva muutos.** Uusi sarake on `NULL`-sallittu tai sillä on oletusarvo, jotta
   nykyinen sovellusversio toimii sekä ennen muutosta että sen jälkeen. Sarakkeen poisto tai uudelleen
   nimeäminen tehdään vaiheittain (expand–contract): lisää uusi, kopioi data, ota käyttöön sovelluksessa,
   poista vanha vasta seuraavassa julkaisussa.
3. **Testaus ensin.** Migraatio ajetaan tuotantokannan kopioon (palautettu varmuuskopio, täysi data):
   mitataan kesto, tarkistetaan lukitus (`ALGORITHM=INSTANT` / `INPLACE, LOCK=NONE` MySQL 8:ssa; jos
   MySQL vaatii taulun kopioinnin, muutos ajetaan hiljaisena aikana) ja ajetaan sovelluksen testit.
4. **Oikeudet.** Uudet taulut ja sarakkeet vaativat yleensä GRANT-päivityksen
   (`GRANT UPDATE (weight_grams) …`), koska sovellusroolin oikeudet ovat sarakekohtaisia. Tämä kuuluu
   samaan migraatioon.
5. **Varmistus.** Tuoreen varmuuskopion pitää onnistua juuri ennen ajoa. Palautusohje ja peruutus-SQL
   (`ALTER TABLE products DROP COLUMN weight_grams`) kirjoitetaan valmiiksi.
6. **Tiedottaminen.** Huoltoikkuna sovitaan ja tiedotetaan etukäteen (kehittäjät, asiakaspalvelu,
   tarvittaessa asiakkaat). Muutoksen jälkeen ilmoitetaan, kun muutos on tehty.
7. **Ajo ja seuranta.** Ylläpitäjä (`webstore_admin`) ajaa migraation hiljaisena aikana. Sen jälkeen
   ajetaan tarkistuskysely ja savutesti ja seurataan virhelokeja ja hitaita kyselyjä. Ongelmatilanteessa
   ajetaan peruutus-SQL tai palautetaan varmuuskopio.

Tämän projektin migraatiot noudattavat samaa mallia: `kanta/asenna.ps1` ajaa versiot V01–V08
järjestyksessä, ja `00_asennuksen_tarkistus.sql` todentaa lopputuloksen.

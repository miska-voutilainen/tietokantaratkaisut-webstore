# Lukitus ja samanaikaisuus

Testit: `kanta/testit/lukitus/`, ajo: `kanta/aja_testit.ps1`. Tuloste: `todennukset/08_lukitus.txt`.
JPA-tason testi: `MySqlIntegrationTest.concurrentOrdersCannotOversell`.

## Tilanne

Kaksi asiakasta ostaa samaan aikaan saman tuotteen viimeisiä kappaleita. Tuotteella 899 on varastossa
3 kpl, ja kumpikin ostaa 2 kpl. Oikea lopputulos: yksi osto hyväksytään ja toinen hylätään, saldo on 1.

```
aika  istunto A                          istunto B
0,0   lukee saldon (3), riittää
0,5                                      lukee saldon (3), riittää
2,0   UPDATE saldo -> 1  (rivilukko)
2,5                                      UPDATE … odottaa A:n lukkoa
4,0   COMMIT                             … lukko vapautuu, B jatkaa
```

Ongelma on **kadonnut päivitys**: jos kumpikin päättää myynnistä vanhan lukeman perusteella, myydään
4 kpl kolmen kappaleen varastosta.

## Testit kahdella istunnolla

Sama SQL ajetaan kahdessa yhteydessä 0,5 s välein (`--init-command` nimeää istunnot A ja B). Kolmas
istunto lukee `sys.innodb_lock_waits`-näkymää kesken ajon.

### 1. Ilman eksplisiittistä lukkoa: luku + laskettu kirjoitus

```sql
SELECT stock_quantity INTO @stock FROM products WHERE id = 899;            -- tavallinen SELECT
UPDATE products SET stock_quantity = @stock - 2 WHERE id = 899 AND @stock >= 2;
```

| Istunto | Luettu saldo | Myynti hyväksytty | UPDATE valmis |
|---|---|---|---|
| A | 3 (15:54:10.19) | 1 | 15:54:12.20 |
| B | 3 (15:54:10.71) | 1 | 15:54:14.22, odotti A:n COMMITia noin 1,5 s |

Lopullinen saldo on **1, mutta kumpikin myynti hyväksyttiin**. InnoDB:n automaattinen rivilukko toimi:
B:n UPDATE odotti (seuranta: `RECORD`-lukko `PRIMARY`-indeksissä, odottanut 1 s). Lukko kuitenkin
suojaa vain kirjoitusta. B:n SELECT luki tilannekuvan ilman lukkoa, joten B kirjoitti vanhaan lukemaan
perustuvan arvon, ja A:n päivitys katosi.

### 2. Automaattinen lukko ja atominen UPDATE

```sql
UPDATE products SET stock_quantity = stock_quantity - 2
 WHERE id = 899 AND stock_quantity >= 2;
```

A päivitti 1 rivin. B:n UPDATE odotti lukkoa ja arvioi lukon vapauduttua ehdon uudelleen tuoreesta
arvosta (1 ≥ 2 on epätosi), joten se **päivitti 0 riviä**. Saldo on 1, ja vain A:n myynti toteutui.
Sovellus tulkitsee 0 riviä niin, että saldo ei riittänyt.

### 3. Eksplisiittinen lukko: `SELECT … FOR UPDATE`

```sql
SELECT stock_quantity INTO @stock FROM products WHERE id = 899 FOR UPDATE;
```

| Istunto | Lukon saanti | Luettu saldo | Myynti hyväksytty |
|---|---|---|---|
| A | 15:54:22.58 heti | 3 | 1 |
| B | 15:54:26.61, odotti noin 3,5 s A:n COMMITiin | **1** | **0** |

Seuranta näytti B:n `SELECT … FOR UPDATE` -lauseen odottavan A:ta. B sai lukon vasta A:n COMMITin
jälkeen ja luki silloin vahvistetun arvon 1. Saldo on 1, ja B:n myynti hylättiin.

## Ero ja arvio

| | Ilman lukkoa (luku + kirjoitus) | Atominen UPDATE | SELECT … FOR UPDATE |
|---|---|---|---|
| Oikea tulos | Ei | Kyllä | Kyllä |
| Lukon kesto | Vain UPDATEsta COMMITiin | Vain UPDATEsta COMMITiin | Luvusta COMMITiin |
| Odotus | B odottaa kirjoituksessa | B odottaa kirjoituksessa | B odottaa jo lukiessa |

**Automaattinen lukitus riittää**, kun tarkistus ja muutos mahtuvat samaan lauseeseen. Tämä koskee
projektin tärkeintä tilannetta, varastosaldon vähennystä. Sovellus tekee sen nyt juuri niin
(`ProductRepository.decreaseStockIfAvailable`). JPA-integraatiotestissä kaksi säiettä tilasi 2 kpl
kolmen kappaleen saldosta, ja tulos oli `[TORJUTTU, OK]` ja loppusaldo 1. Sama koskee massapäivityksiä
(`cancel-stale`, `restock`), sillä yksi lause lukitsee rivinsä itse.

**Eksplisiittinen lukko on perusteltu**, kun päätös vaatii useita lukuja tai logiikkaa ennen
kirjoitusta, eikä sitä voi ilmaista yhdellä lauseella. Esimerkkejä:
- `place_order_transaction` ja `change_product_price` lukevat hinnan ja saldon, tarkistavat ehtoja
  (esim. hinnanmuutos enintään 50 %) ja kirjoittavat usean taulun. Ne käyttävät `FOR UPDATE`-lukkoa,
  jotta luettu arvo pysyy voimassa transaktion loppuun.
- Taulutason lukkoa (`LOCK TABLES`) ei tarvita missään. Se pysäyttäisi koko verkkokaupan tilaukset.

Eksplisiittinen lukko pidentää lukon kestoa ja kasvattaa odotusta (skenaariossa 3 B odotti noin 3,5 s, skenaariossa 1 noin 1,5 s), joten se
rajataan lyhyisiin transaktioihin. Käyttäjän ajattelutaukojen yli ulottuvat muutokset (lomakkeella
muokattu tuote) suojataan optimistisella lukituksella (`@Version`). Se ei pidä lukkoa lainkaan vaan
hylkää vanhentuneen tallennuksen (`OptimisticLockingTest`).

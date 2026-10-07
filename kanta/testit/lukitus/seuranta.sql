-- Kolmas istunto: kuka odottaa kenen lukkoa juuri nyt.
SELECT SYSDATE(6) AS aika,
       w.waiting_query   AS odottava_lause,
       w.blocking_query  AS estava_lause,
       w.wait_age        AS odottanut,
       w.locked_table    AS taulu,
       w.locked_index    AS indeksi,
       w.locked_type     AS lukon_tyyppi
FROM sys.innodb_lock_waits w;

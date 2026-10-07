# Ajaa tietokannan todennustestit oikeilla käyttäjillä ja tallentaa tulosteet kansioon
# dokumentaatio/todennukset. Aja asenna.ps1:n jälkeen samoilla salasanoilla.
#
#   .\kanta\aja_testit.ps1 -RootPassword 'salasana'
param(
    [Parameter(Mandatory = $true)]
    [string]$RootPassword,

    [string]$DbHost = '127.0.0.1',
    [int]$Port = 3306,

    [string]$AdminPassword = 'Admin_vaihda_2026!',
    [string]$AppPassword = 'App_vaihda_2026!',
    [string]$ReportPassword = 'Report_vaihda_2026!',

    [string]$MysqlBin = 'C:\Program Files\MySQL\MySQL Server 8.0\bin'
)

$ErrorActionPreference = 'Stop'
$mysql = Join-Path $MysqlBin 'mysql.exe'
$tests = Join-Path $PSScriptRoot 'testit'
$out = Join-Path (Split-Path -Parent $PSScriptRoot) 'dokumentaatio\todennukset'
New-Item -ItemType Directory -Force $out | Out-Null

$users = @{
    root            = $RootPassword
    webstore_admin  = $AdminPassword
    webstore_app    = $AppPassword
    webstore_report = $ReportPassword
}

# -vvv tulostaa myös ajetut lauseet; --force jatkaa tarkoituksellisten virheiden jälkeen.
function Invoke-Test([string]$user, [string]$sqlFile, [string]$outFile, [switch]$Force) {
    $env:MYSQL_PWD = $users[$user]
    try {
        $forceArg = if ($Force) { '--force' } else { '' }
        cmd /c "`"$mysql`" --protocol=tcp -h $DbHost -P $Port -u $user --table -vvv --default-character-set=utf8mb4 $forceArg < `"$sqlFile`" > `"$outFile`" 2>&1"
    } finally {
        Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
    }
}

function Start-Session([string]$user, [string]$sqlFile, [string]$outFile, [string]$who) {
    $env:MYSQL_PWD = $users[$user]
    try {
        return Start-Process -FilePath $mysql -NoNewWindow -PassThru `
            -ArgumentList @('--protocol=tcp', '-h', $DbHost, '-P', $Port, '-u', $user, '--table',
                            '--default-character-set=utf8mb4', "`"--init-command=SET @who='$who'`"") `
            -RedirectStandardInput $sqlFile -RedirectStandardOutput $outFile -RedirectStandardError "$outFile.err"
    } finally {
        Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
    }
}

Write-Output 'Indeksit: EXPLAIN ANALYZE'
Invoke-Test root (Join-Path $tests 'indeksointi_kyselyt.sql') (Join-Path $out '01_indeksit_jalkeen.txt')
Write-Output 'Hintahistoria'
Invoke-Test webstore_app (Join-Path $tests '02_hintahistoria_testi.sql') (Join-Path $out '02_hintahistoria.txt')
Write-Output 'Liipaisimet'
Invoke-Test webstore_admin (Join-Path $tests '03_liipaisimet_testi.sql') (Join-Path $out '03_liipaisimet.txt') -Force
Write-Output 'Ajastettu tapahtuma'
Invoke-Test root (Join-Path $tests '04_tapahtuma_testi.sql') (Join-Path $out '04_tapahtuma.txt')
Write-Output 'Oikeudet: sovellus'
Invoke-Test webstore_app (Join-Path $tests '05_oikeudet_testi.sql') (Join-Path $out '05_oikeudet_app.txt') -Force
Write-Output 'Oikeudet: raportointi'
Invoke-Test webstore_report (Join-Path $tests '06_raportointi_oikeudet_testi.sql') (Join-Path $out '06_oikeudet_raportointi.txt') -Force
Write-Output 'Näkymät'
Invoke-Test webstore_admin (Join-Path $tests '07_nakymat_testi.sql') (Join-Path $out '07_nakymat.txt')

# Lukitusskenaariot: istunnot A ja B käynnistetään 0,5 s välein, ja kolmas istunto katsoo lukkojonoa
# kesken kaiken. Molemmat yrittävät ostaa 2 kpl tuotetta, jota on varastossa 3 kpl.
$lockDir = Join-Path $tests 'lukitus'
$lockReport = Join-Path $out '08_lukitus.txt'
$tmp = [IO.Path]::GetTempPath()
Set-Content -LiteralPath $lockReport -Value '' -Encoding utf8
foreach ($scenario in '1_luku_ja_kirjoitus_ilman_lukkoa', '2_atominen_update', '3_select_for_update') {
    Write-Output "Lukitus: $scenario"
    $prefix = Join-Path $tmp "webstore_lock_$scenario"
    Invoke-Test webstore_admin (Join-Path $lockDir '00_alusta.sql') "$prefix.alku.txt"

    $a = Start-Session webstore_app (Join-Path $lockDir "$scenario.sql") "$prefix.A.txt" 'A'
    Start-Sleep -Milliseconds 500
    $b = Start-Session webstore_app (Join-Path $lockDir "$scenario.sql") "$prefix.B.txt" 'B'
    Start-Sleep -Milliseconds 2500
    Invoke-Test root (Join-Path $lockDir 'seuranta.sql') "$prefix.seuranta.txt"
    $a.WaitForExit(); $b.WaitForExit()
    Invoke-Test webstore_admin (Join-Path $lockDir 'loppu.sql') "$prefix.loppu.txt"

    $section = @("==================== $scenario ====================")
    foreach ($part in 'alku', 'A', 'B', 'seuranta', 'loppu') {
        $section += "---------- $part ----------"
        $section += Get-Content -LiteralPath "$prefix.$part.txt" -Encoding utf8
        if (Test-Path "$prefix.$part.txt.err") { $section += Get-Content -LiteralPath "$prefix.$part.txt.err" -Encoding utf8 }
        Remove-Item -LiteralPath "$prefix.$part.txt", "$prefix.$part.txt.err" -ErrorAction SilentlyContinue
    }
    Add-Content -LiteralPath $lockReport -Value $section -Encoding utf8
}

Write-Output "Tulosteet: $out"

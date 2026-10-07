# Rakentaa koko webstore-tietokannan yhdellä ajolla:
#   1. poistaa ja luo webstore-skeeman
#   2. lataa perusskeeman ja datan dumpista (populoitu tai tyhjä)
#   3. kokoaa migraatiot V01..V08 tiedostoon webstore_migraatiot.sql ja ajaa sen
#
# Esimerkki:
#   .\kanta\asenna.ps1 -RootPassword 'salasana'
#   .\kanta\asenna.ps1 -RootPassword 'salasana' -Data tyhja -AppPassword 'oma_app_salasana'
#
# HUOM: olemassa oleva webstore-skeema poistetaan kokonaan.
param(
    [Parameter(Mandatory = $true)]
    [string]$RootPassword,

    [string]$DbHost = '127.0.0.1',
    [int]$Port = 3306,

    [ValidateSet('populoitu', 'tyhja')]
    [string]$Data = 'populoitu',

    [string]$AdminPassword = 'Admin_vaihda_2026!',
    [string]$AppPassword = 'App_vaihda_2026!',
    [string]$ReportPassword = 'Report_vaihda_2026!',

    [string]$MysqlBin = 'C:\Program Files\MySQL\MySQL Server 8.0\bin'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$mysql = Join-Path $MysqlBin 'mysql.exe'
$migrationDir = Join-Path $PSScriptRoot 'migraatiot'
$combinedFile = Join-Path $PSScriptRoot 'webstore_migraatiot.sql'
$utf8 = New-Object System.Text.UTF8Encoding($false)

$dump = if ($Data -eq 'populoitu') { 'schema_populated_dump.sql' } else { 'schema_no_data_dump.sql' }
$dumpPath = Join-Path $root $dump

# Populoitu dump on versionhallinnassa pakattuna (GitHubin 100 Mt:n tiedostoraja). Puretaan kerran.
if (-not (Test-Path -LiteralPath $dumpPath) -and (Test-Path -LiteralPath "$dumpPath.gz")) {
    Write-Output "Puretaan $dump.gz"
    $in = [IO.File]::OpenRead("$dumpPath.gz")
    $out = [IO.File]::Create($dumpPath)
    try {
        $gzip = New-Object System.IO.Compression.GZipStream($in, [IO.Compression.CompressionMode]::Decompress)
        $gzip.CopyTo($out)
    } finally {
        $out.Dispose()
        $in.Dispose()
    }
}

function Invoke-MysqlFile([string]$file, [string]$database) {
    $env:MYSQL_PWD = $RootPassword
    try {
        $dbArg = if ($database) { $database } else { '' }
        cmd /c "`"$mysql`" --protocol=tcp -h $DbHost -P $Port -u root --default-character-set=utf8mb4 $dbArg < `"$file`""
        if ($LASTEXITCODE -ne 0) { throw "mysql epäonnistui tiedostolla $file" }
    } finally {
        Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
    }
}

# Migraatiot yhdeksi tiedostoksi, jotta koko muutosjoukko on luettavissa ja ajettavissa yhtenä kokonaisuutena.
$parts = @("-- Koottu tiedostoista kanta/migraatiot/V*.sql. Älä muokkaa käsin, aja kanta/asenna.ps1.", "USE webstore;", "")
foreach ($file in Get-ChildItem -LiteralPath $migrationDir -Filter 'V*.sql' | Sort-Object Name) {
    $parts += "-- ===== $($file.Name) ====="
    $parts += [IO.File]::ReadAllText($file.FullName, $utf8)
}
[IO.File]::WriteAllText($combinedFile, ($parts -join "`n"), $utf8)
Write-Output "Migraatiot koottu: $combinedFile"

# Salasanat korvataan vain väliaikaiseen kopioon, ei versionhallittavaan tiedostoon.
$tempFile = Join-Path ([IO.Path]::GetTempPath()) ("webstore_migraatiot_{0}.sql" -f [guid]::NewGuid())
$sql = [IO.File]::ReadAllText($combinedFile, $utf8)
$sql = $sql.Replace('__ADMIN_PASSWORD__', $AdminPassword.Replace("'", "''"))
$sql = $sql.Replace('__APP_PASSWORD__', $AppPassword.Replace("'", "''"))
$sql = $sql.Replace('__REPORT_PASSWORD__', $ReportPassword.Replace("'", "''"))
[IO.File]::WriteAllText($tempFile, $sql, $utf8)

$resetFile = Join-Path ([IO.Path]::GetTempPath()) ("webstore_reset_{0}.sql" -f [guid]::NewGuid())
[IO.File]::WriteAllText($resetFile, "DROP DATABASE IF EXISTS webstore;`nCREATE DATABASE webstore CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;`n", $utf8)

try {
    Write-Output "1/3 Luodaan webstore-skeema uudelleen"
    Invoke-MysqlFile $resetFile $null

    Write-Output "2/3 Ladataan $dump"
    Invoke-MysqlFile $dumpPath 'webstore'

    Write-Output "3/3 Ajetaan migraatiot"
    Invoke-MysqlFile $tempFile $null
} finally {
    Remove-Item -LiteralPath $tempFile, $resetFile -ErrorAction SilentlyContinue
}

$checkFile = Join-Path $PSScriptRoot 'testit\00_asennuksen_tarkistus.sql'
Invoke-MysqlFile $checkFile 'webstore'
Write-Output "Valmis."

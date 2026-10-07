param(
    [Parameter(Mandatory = $true)]
    [string]$Password,

    [int]$Concurrency = 20,
    [int]$Iterations = 5,
    [int]$TotalQueries = 100,

    [switch]$SkipWarmup
)

$mysqlslap = 'C:\Program Files\MySQL\MySQL Server 8.0\bin\mysqlslap.exe'
$queryFiles = Get-ChildItem -LiteralPath $PSScriptRoot -Filter '??_*.sql' | Sort-Object Name

foreach ($queryFile in $queryFiles) {
    Write-Output "QUERY=$($queryFile.Name)"
    if (-not $SkipWarmup) {
        & $mysqlslap `
            --protocol=tcp `
            -h 127.0.0.1 `
            -P 3306 `
            -u root `
            "--password=$Password" `
            --create-schema=webstore `
            "--concurrency=$Concurrency" `
            --iterations=1 `
            "--number-of-queries=$Concurrency" `
            "--query=$($queryFile.FullName)" `
            '--delimiter=;' 2>$null | Out-Null
    }

    & $mysqlslap `
        --protocol=tcp `
        -h 127.0.0.1 `
        -P 3306 `
        -u root `
        "--password=$Password" `
        --create-schema=webstore `
        "--concurrency=$Concurrency" `
        "--iterations=$Iterations" `
        "--number-of-queries=$TotalQueries" `
        "--query=$($queryFile.FullName)" `
        '--delimiter=;'
}

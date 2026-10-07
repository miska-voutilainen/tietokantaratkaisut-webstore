# Ajaa API:n pääpolut käynnissä olevaa sovellusta vasten ja tarkistaa massaoperaatioiden vaikutuksen
# SELECTillä ennen ja jälkeen. Käynnistä sovellus ensin:  mvn spring-boot:run
#
#   .\jpa\api_demo.ps1 > dokumentaatio\todennukset\09_api_demo.txt
param(
    [string]$BaseUrl = 'http://localhost:8080',
    [string]$DbHost = '127.0.0.1',
    [int]$Port = 3306,
    [string]$AppPassword = 'App_vaihda_2026!',
    [string]$MysqlBin = 'C:\Program Files\MySQL\MySQL Server 8.0\bin'
)

$ErrorActionPreference = 'Stop'
$mysql = Join-Path $MysqlBin 'mysql.exe'
$utf8 = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = $utf8

function Sql([string]$query) {
    Write-Output "SQL> $query"
    $env:MYSQL_PWD = $AppPassword
    try {
        & $mysql --protocol=tcp -h $DbHost -P $Port -u webstore_app --table --default-character-set=utf8mb4 webstore -e $query
    } finally {
        Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
    }
    Write-Output ''
}

function Api([string]$method, [string]$path, [string]$body) {
    Write-Output "$method $path"
    if ($body) { Write-Output "  $body" }
    $tmp = [IO.Path]::GetTempFileName()
    try {
        $curlArgs = @('-s', '-X', $method, '-w', "`n  -> HTTP %{http_code}", "$BaseUrl$path")
        if ($body) {
            [IO.File]::WriteAllText($tmp, $body, $utf8)
            $curlArgs += @('-H', 'Content-Type: application/json', '--data-binary', "@$tmp")
        }
        & curl.exe @curlArgs
    } finally {
        Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
    }
    Write-Output "`n"
}

Write-Output '===== Perusresurssit ====='
Api GET '/api/customers/4242'
Api POST '/api/customers' '{"firstName":"Maija","lastName":"Meikäläinen","email":"maija.demo@example.com","phone":"0401234567"}'
Api GET '/api/products/3'
Api PUT '/api/products/3' '{"name":"Quantum Widget 457","description":"Päivitetty kuvaus","stockQuantity":313,"categoryId":3,"supplierId":17}'
Api DELETE '/api/products/3'

Write-Output '===== Criteria API: dynaaminen tuotehaku ====='
Api GET '/api/products?categoryId=1&maxPrice=50&inStock=true&limit=5'
Api GET '/api/products?name=quantum&minPrice=500&limit=5'

Write-Output '===== Tilaus: atominen saldon vähennys ja tilaloki (liipaisin) ====='
Sql 'SELECT id, stock_quantity FROM products WHERE id IN (5, 6)'
Api POST '/api/orders' '{"customerId":4242,"items":[{"productId":5,"quantity":2},{"productId":6,"quantity":1}]}'
Sql 'SELECT id, stock_quantity FROM products WHERE id IN (5, 6)'
Api POST '/api/orders' '{"customerId":4242,"items":[{"productId":5,"quantity":1},{"productId":6,"quantity":100000}]}'
Sql 'SELECT id, stock_quantity FROM products WHERE id IN (5, 6)'
$orderId = (& curl.exe -s "$BaseUrl/api/customers/4242/orders" | ConvertFrom-Json)[0].id
Api GET "/api/orders/$orderId"
Api PUT "/api/orders/$orderId/status" '{"status":"SHIPPED"}'
Api GET "/api/orders/$orderId/status-history"

Write-Output '===== Hintahistoria: proseduuri ja temporaalinen haku ====='
Api PUT '/api/products/9/price' '{"price":99999,"reason":"näppäilyvirhe"}'
Api PUT '/api/products/9/price' '{"price":1.00,"reason":"liian suuri muutos"}'
Sql 'SELECT id, price, version FROM products WHERE id = 9'
$before = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')
Start-Sleep -Seconds 1
Api GET '/api/products/9'
$json = & curl.exe -s "$BaseUrl/api/products/9" | ConvertFrom-Json
$newPrice = [math]::Round($json.price * 0.9, 2).ToString([Globalization.CultureInfo]::InvariantCulture)
Api PUT '/api/products/9/price' "{`"price`":$newPrice,`"reason`":`"kampanja -10 %`"}"
Api GET '/api/products/9/price-history'
Api GET "/api/products/9/price-at?at=$before"

Write-Output '===== JPQL: myynti tuoteryhmittäin (GROUP BY) ====='
Api GET '/api/reports/sales-by-category?from=2025-01-01&to=2025-04-01'

Write-Output '===== JPQL @Modifying: vanhojen käsittelemättömien tilausten peruminen ====='
Sql "SELECT status, COUNT(*) AS lkm FROM orders WHERE order_date < '2024-06-01' GROUP BY status"
Api POST '/api/admin/orders/cancel-stale?before=2024-06-01'
Sql "SELECT status, COUNT(*) AS lkm FROM orders WHERE order_date < '2024-06-01' GROUP BY status"
Sql "SELECT COUNT(*) AS liipaisimen_lokirivit FROM order_status_history WHERE new_status = 'CANCELLED' AND changed_by LIKE 'webstore_app@%'"

Write-Output '===== CriteriaUpdate: vähissä olevien tuotteiden täydennys ====='
Sql 'SELECT supplier_id, id, stock_quantity, version FROM products WHERE stock_quantity < 60 ORDER BY supplier_id, id'
Api POST '/api/admin/products/restock' '{"threshold":60,"amount":40}'
Sql 'SELECT COUNT(*) AS alle_60_kpl FROM products WHERE stock_quantity < 60'

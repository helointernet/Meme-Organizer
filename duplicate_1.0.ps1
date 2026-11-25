param(
    [string]$imageHash,
    [string]$dbPath,
    [string]$sqlPath
)
$ErrorActionPreference = "Stop"

$query = @"
SELECT current_path
FROM memes
WHERE original_hash = '$imageHash'
LIMIT 1;
"@

$result = & $sqlPath -noheader -batch $dbPath $query 2>$null

Write-Output ($result | Select-Object -First 1)
param(
	[string]$json,
	[string]$processedHash
)
$ErrorActionPreference = "Stop"

$data = $json | ConvertFrom-Json

$data | Add-Member -NotePropertyName "processed_hash" -NotePropertyValue $processedHash -Force

$finalJson = $data | ConvertTo-Json -Depth 20 -Compress

[Console]::Out.Write($finalJson)
param(
    [string]$source
)
$ErrorActionPreference = "Stop"

$hash = (Get-FileHash $source -Algorithm MD5).Hash.ToLowerInvariant()

[Console]::Out.Write($hash)
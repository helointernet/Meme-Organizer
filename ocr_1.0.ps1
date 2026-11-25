param(
    [string]$ocrRaw
)

$ErrorActionPreference = "Stop"
$MaxLength = 1800

# Keep this intentionally simple:
# - preserve ASCII letters A-Z and a-z
# - preserve spaces
# - remove punctuation, numbers, symbols, accents, emoji, control characters, etc.
# - collapse all whitespace to one space

if ([string]::IsNullOrWhiteSpace($ocrRaw)) {
    [Console]::Out.Write("")
    exit 0
}

$ocrClean = $ocrRaw

# Turn any whitespace character, including newlines and tabs, into a regular space.
$ocrClean = $ocrClean -replace '\s+', ' '

# Remove everything except normal ASCII English letters and spaces.
$ocrClean = $ocrClean -replace '[^A-Za-z ]', ''

# Collapse extra spaces caused by removed characters.
$ocrClean = $ocrClean -replace ' +', ' '
$ocrClean = $ocrClean.Trim()

if ($MaxLength -gt 0 -and $ocrClean.Length -gt $MaxLength) {
    $ocrClean = $ocrClean.Substring(0, $MaxLength).Trim()
}

[Console]::Out.Write($ocrClean)
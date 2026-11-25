param(
    [string]$json,
    [string]$normalHash
)
$ErrorActionPreference = "Stop"

function ConvertTo-SearchSlug {
    param(
        [AllowNull()][string]$Text,
        [int]$MaxWords = 10,
        [int]$MaxChars = 80
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }

    $stopWords = @(
        "the","and","for","you","your","are","was","were","with","this","that",
        "from","have","has","had","but","not","all","out","who","what","when",
        "where","why","how","into","onto","about","until","then","than","they",
        "them","there","their","its","hes","he","she","him","her","his",
        "our","we","us","a","an","of","to","in","on","at","by","or","as","is",
        "be","do","does","did","it","i","me","my"
    )

    $lower = ([string]$Text).ToLowerInvariant()

    # Filename slugs are intentionally strict: ASCII letters/numbers only.
    $matches = [regex]::Matches($lower, "[a-z0-9]+")

    $words = New-Object System.Collections.Generic.List[string]
    $seen = @{}

    foreach ($m in $matches) {
        $word = $m.Value

        if ($word.Length -lt 2) { continue }
        if ($stopWords -contains $word) { continue }
        if ($seen.ContainsKey($word)) { continue }

        $seen[$word] = $true
        $words.Add($word)

        if ($words.Count -ge $MaxWords) { break }
    }

    if ($words.Count -eq 0) {
        return ""
    }

    $slug = ($words -join "-")

    if ($slug.Length -gt $MaxChars) {
        $slug = $slug.Substring(0, $MaxChars)
        $slug = $slug -replace "-[^-]*$", ""
        $slug = $slug.Trim("-")
    }

    return $slug
}

function ConvertTo-ArraySlug {
    param(
        [AllowNull()]$Items,
        [int]$MaxItems = 6,
        [int]$MaxWords = 12,
        [int]$MaxChars = 80
    )

    $list = @($Items) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Select-Object -First $MaxItems

    if ($list.Count -eq 0) {
        return ""
    }

    return ConvertTo-SearchSlug -Text ($list -join " ") -MaxWords $MaxWords -MaxChars $MaxChars
}

$data = $json | ConvertFrom-Json

$subjectSlug = ConvertTo-ArraySlug -Items $data.subjects -MaxItems 4 -MaxWords 8 -MaxChars 55

if ([string]::IsNullOrWhiteSpace($subjectSlug)) {
    $subjectSlug = ConvertTo-SearchSlug -Text "$($data.category) meme" -MaxWords 4 -MaxChars 55
}

if ([string]::IsNullOrWhiteSpace($subjectSlug)) {
    $subjectSlug = "meme"
}

$shortHash = $normalHash.Substring(0, 8)
$ocrSlug = ConvertTo-SearchSlug -Text $data.visible_text -MaxWords 12 -MaxChars 80
$tagSlug = ConvertTo-ArraySlug -Items $data.tags -MaxItems 8 -MaxWords 12 -MaxChars 80

if (-not [string]::IsNullOrWhiteSpace($ocrSlug)) {
    # Schema when OCR exists:
    # subject-slug_hash_ocr-slug.ext
    $baseName = "$subjectSlug`_$shortHash`_$ocrSlug"
}
else {
    # Schema when OCR is empty:
    # subject-slug_hash_tag-slug.ext
    if ([string]::IsNullOrWhiteSpace($tagSlug)) {
        $tagSlug = "meme"
    }

    $baseName = "$subjectSlug`_$shortHash`_$tagSlug"
}

$newFileName = $baseName

# Keep filename from getting stupidly long.
if ($newFileName.Length -gt 150) {
    $maxBaseLength = 150
    if ($maxBaseLength -lt 1) {
        $maxBaseLength = 1
    }

    $baseName = $baseName.Substring(0, [Math]::Min($baseName.Length, $maxBaseLength))
    $baseName = $baseName.Trim("-", "_", ".", " ")
    $newFileName = $baseName
}

[Console]::Out.Write($newFileName)
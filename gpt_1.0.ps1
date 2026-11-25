param(
    [string]$originalHash,
	[string]$normalHash,
    [string]$processedAt,
    [string]$ocrText,
    [string]$originalName,
    [string]$version,
    [string]$debugFolder,
    [string]$imagePath,
	[string]$safeFile
)
$ErrorActionPreference = "Stop"
$mimeType = "image/png"

function Remove-QuoteChars {
    param([AllowNull()][string]$Text)

    if ($null -eq $Text) {
        return ""
    }

    $clean = [string]$Text

    # Remove straight quotes, apostrophes, backticks, acute accents,
    # curly quotes, guillemets, and prime marks.
    $clean = $clean -replace '[\u0022\u0027\u0060\u00B4\u2018\u2019\u201A\u201B\u201C\u201D\u201E\u201F\u2032\u2033\u2035\u2036\u00AB\u00BB\u2039\u203A]', ''

    # Collapse whitespace after removals.
    $clean = $clean -replace '\s+', ' '
    $clean = $clean.Trim()

    return $clean
}

function ConvertTo-CleanOcrText {
    param(
        [AllowNull()][string]$Text,
        [int]$MaxLength = 1800
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }

    # Keep this intentionally brutal for archive/search safety:
    # ASCII A-Z / a-z plus spaces only. No punctuation. No numbers. No accents.
    $clean = [string]$Text
    $clean = $clean -replace '\s+', ' '
    $clean = $clean -replace '[^A-Za-z ]', ''
    $clean = $clean -replace ' +', ' '
    $clean = $clean.Trim()

    if ($MaxLength -gt 0 -and $clean.Length -gt $MaxLength) {
        $clean = $clean.Substring(0, $MaxLength).Trim()
    }

    return $clean
}

function Split-CamelCase {
    param([AllowNull()][string]$Text)

    if ($null -eq $Text) {
        return ""
    }

    $out = [string]$Text

    # XMLParserThing -> XML Parser Thing
    $out = $out -creplace '([A-Z]+)([A-Z][a-z])', '$1 $2'

    # sailorSaturn / SailorSaturn -> sailor Saturn / Sailor Saturn
    $out = $out -creplace '([a-z])([A-Z])', '$1 $2'

    # word123word -> word 123 word, so later alphanumeric/id cleanup can judge pieces.
    $out = $out -creplace '([A-Za-z])(\d)', '$1 $2'
    $out = $out -creplace '(\d)([A-Za-z])', '$1 $2'

    return $out
}

function ConvertTo-FilenameHint {
    param(
        [AllowNull()][string]$FileName,
        [int]$MaxWords = 12,
        [int]$MaxChars = 120
    )

    if ([string]::IsNullOrWhiteSpace($FileName)) {
        return ""
    }

    $commonJunk = @(
        "image", "images", "img", "istockphoto", "download", "downloads", "downloaded",
        "file", "files", "picture", "pictures", "pic", "pics",
        "photo", "photos", "photograph", "photographs",
        "screenshot", "screenshots", "screen", "shot", "capture", "captures",
        "copy", "final", "edit", "edited", "original", "orig",
        "resized", "resize", "scaled", "scale", "crop", "cropped",
        "unknown", "untitled", "upload", "uploads", "media",
        "large", "small", "thumb", "thumbnail", "tumblr", "preview", "view",
        "format", "jpg", "jpeg", "png", "webp", "gif", "bmp", "tif", "tiff",
        "heic", "heif", "avif", "jxl", "mp4", "webm",
        "www", "com", "net", "org", "cdn", "static", "asset", "assets",
        "new", "old", "temp", "tmp", "save", "saved"
    )

    # Short tokens are usually junk, but a few are meaningful character/name hints.
    $shortHintWhitelist = @(
        "al", "io", "ai", "tv", "db", "jr", "mj", "us", "uk"
    )

    try {
        $stem = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
    }
    catch {
        $stem = [string]$FileName
    }

    $stem = Remove-QuoteChars $stem
    $stem = Split-CamelCase $stem

    # Convert snake case, dash-separated words, dots, and other separators to spaces.
    $stem = $stem -replace '[_\-\.]+', ' '

    # Remove remaining punctuation/symbols while keeping letters, digits, and spaces.
    $stem = $stem -replace '[^A-Za-z0-9 ]', ' '
    $stem = $stem -replace '\s+', ' '
    $stem = $stem.Trim()

    if ([string]::IsNullOrWhiteSpace($stem)) {
        return ""
    }

    $rawTokens = $stem -split '\s+'
    $tokens = New-Object System.Collections.Generic.List[string]
    $seen = @{}

    foreach ($rawToken in $rawTokens) {
        if ([string]::IsNullOrWhiteSpace($rawToken)) {
            continue
        }

        $token = $rawToken.ToLowerInvariant()

        # Drop pure numeric chunks and obvious file ids.
        if ($token -match '^\d+$') {
            continue
        }

        # Strip leading/trailing digits: 1nadler1 -> nadler, img2024 -> img.
        $token = $token -replace '^\d+', ''
        $token = $token -replace '\d+$', ''

        # Strip common decorative x wrappers: xxciceroxx -> cicero.
        if ($token -match '^x{1,3}([a-z]{3,})x{1,3}$') {
            $token = $Matches[1]
        }

        # If digits remain inside, treat it as an id/model/blob rather than a useful word.
        if ($token -notmatch '^[a-z]+$') {
            continue
        }

        if ($commonJunk -contains $token) {
            continue
        }

        # Drop tiny tokens unless explicitly whitelisted.
        if ($token.Length -lt 3 -and -not ($shortHintWhitelist -contains $token)) {
            continue
        }

        # Drop suspiciously long solid strings. This avoids hashes/CDN blobs and
        # lower-case run-on strings we cannot reliably word-break with simple logic.
        if ($token.Length -gt 24) {
            continue
        }

        # Drop repeated-character junk.
        if ($token -match '^(.)\1{2,}$') {
            continue
        }

        # Drop long no-vowel chunks. Keep short acronyms like gpt npc cnn etc.
        if ($token.Length -ge 5 -and $token -notmatch '[aeiouy]') {
            continue
        }

        if ($seen.ContainsKey($token)) {
            continue
        }

        $seen[$token] = $true
        $tokens.Add($token)

        if ($tokens.Count -ge $MaxWords) {
            break
        }
    }

    if ($tokens.Count -eq 0) {
        return ""
    }

    $hint = ($tokens -join ' ')

    if ($MaxChars -gt 0 -and $hint.Length -gt $MaxChars) {
        $hint = $hint.Substring(0, $MaxChars).Trim()
        $hint = $hint -replace '\s+\S*$', ''
        $hint = $hint.Trim()
    }

    return $hint
}

function Sanitize-MemeDataStrings {
    param([Parameter(Mandatory=$true)]$MemeData)

    if ($MemeData.PSObject.Properties.Name -contains "summary") {
        $MemeData.summary = Remove-QuoteChars $MemeData.summary
    }

    if ($MemeData.PSObject.Properties.Name -contains "subjects") {
        $MemeData.subjects = @(
            foreach ($subject in @($MemeData.subjects)) {
                Remove-QuoteChars $subject
            }
        )
    }

    if ($MemeData.PSObject.Properties.Name -contains "tags") {
        $MemeData.tags = @(
            foreach ($tag in @($MemeData.tags)) {
                Remove-QuoteChars $tag
            }
        )
    }

    return $MemeData
}

$tracePath = "$debugFolder\debug_powershell_trace_$safeFile.txt"
$responsePath = "$debugFolder\debug_full_response_$safeFile.json"

try {
    "START" | Set-Content -Path $tracePath -Encoding UTF8

    $apiKey = [Environment]::GetEnvironmentVariable("OPENAI_API_KEY", "User")

    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        $apiKey = [Environment]::GetEnvironmentVariable("OPENAI_API_KEY", "Machine")
    }

    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        throw "OPENAI_API_KEY was not found in User or Machine environment variables."
    }

    "API key found" | Add-Content -Path $tracePath -Encoding UTF8

    "Image path: $imagePath" | Add-Content -Path $tracePath -Encoding UTF8
    "MIME type: $mimeType" | Add-Content -Path $tracePath -Encoding UTF8

    # OCR is cleaned here for the final JSON only. It is intentionally NOT added to the GPT prompt.
    $safeOcrClean = ConvertTo-CleanOcrText $ocrText

    # Filename hint is cleaned here and used as weak context in the GPT prompt.
    $filenameHint = ConvertTo-FilenameHint $originalName

    "Filename hint: $filenameHint" | Add-Content -Path $tracePath -Encoding UTF8
    "Clean OCR length: $($safeOcrClean.Length)" | Add-Content -Path $tracePath -Encoding UTF8
    $filenameHint | Set-Content -Path "$debugFolder\debug_filename_hint_$safeFile.txt" -Encoding UTF8
    $safeOcrClean | Set-Content -Path "$debugFolder\debug_ocr_clean_$safeFile.txt" -Encoding UTF8

    $base64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($imagePath))
    $imageDataUrl = "data:{0};base64,{1}" -f $mimeType, $base64

    "Image converted to Base64" | Add-Content -Path $tracePath -Encoding UTF8

    $promptLines = New-Object System.Collections.Generic.List[string]
    $promptLines.Add("Classify this image for a personal meme archive.")
	$promptLines.Add("Identify jokes, wordplay, visual puns, and sarcasm.")
    $promptLines.Add("OCR text is handled separately do not transcribe text from the image.")
    $promptLines.Add("Do not analyze every panel give one overall interpretation.")
    $promptLines.Add("Prefer broad searchable labels over detailed explanation.")
    $promptLines.Add("Use simple filename friendly words in summary, subjects, and tags.")
	$promptLines.Add("Inside JSON string values never use quotation marks apostrophes backticks or curly quotes.")
    $promptLines.Add("Do not quote titles dialogue captions usernames or phrases.")
    $promptLines.Add("Rewrite anything that would need quotation marks into plain unquoted wording.")

    if (-not [string]::IsNullOrWhiteSpace($filenameHint)) {
        $promptLines.Add("Optional sanitized filename hint weak context only: $filenameHint")
        $promptLines.Add("The filename hint may be wrong unrelated abbreviated or machine generated use it only as weak context and never as proof.")
    }

    $promptLines.Add("Return only valid JSON using the requested schema.")
    $promptText = $promptLines -join "`n"

    $promptText | Set-Content -Path "$debugFolder\debug_prompt_$safeFile.txt" -Encoding UTF8

    $headers = @{
        "Authorization" = "Bearer $apiKey"
    }

    $bodyObject = @{
        model = "gpt-5.4-mini"
        reasoning = @{
            effort = "low"
        }
        input = @(
            @{
                role = "user"
                content = @(
                    @{
                        type = "input_text"
                        text = $promptText
                    },
                    @{
                        type = "input_image"
                        image_url = $imageDataUrl
                        detail = "low"
                    }
                )
            }
        )
        text = @{
            format = @{
                type = "json_schema"
                name = "meme_analysis"
                strict = $true
                schema = @{
                    type = "object"
                    properties = @{
                        category = @{
                            type = "string"
                            enum = @(
                                "Animals",
                                "Anime",
                                "History",
                                "Politics",
								"Reaction",
                                "ReligionPhilosophy",
                                "ScienceTechnology",
                                "TVMovies",
								"VideoGames",
                                "Uncategorized"
                            )
                        }
                        summary = @{
                            type = "string"
                            pattern = "^[A-Za-z0-9 -]+$"
                        }
                        subjects = @{
                            type = "array"
                            items = @{
                                type = "string"
                                pattern = "^[A-Za-z0-9 -]+$"
                            }
                        }
                        tags = @{
                            type = "array"
                            items = @{
                                type = "string"
                                pattern = "^[A-Za-z0-9 -]+$"
                            }
                        }
                        confidence = @{
                            type = "number"
                        }
                    }
                    required = @(
                        "category",
                        "summary",
                        "subjects",
                        "tags",
                        "confidence"
                    )
                    additionalProperties = $false
                }
            }
        }
        max_output_tokens = 1200
    }

    $bodyJson = $bodyObject | ConvertTo-Json -Depth 20 -Compress
    $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($bodyJson)

    "Sending request to OpenAI" | Add-Content -Path $tracePath -Encoding UTF8

    $response = Invoke-RestMethod `
        -Uri "https://api.openai.com/v1/responses" `
        -Method Post `
        -Headers $headers `
        -ContentType "application/json; charset=utf-8" `
        -Body $bodyBytes

    "Response received" | Add-Content -Path $tracePath -Encoding UTF8

    $response | ConvertTo-Json -Depth 30 | Set-Content -Path $responsePath -Encoding UTF8

    "Full response written" | Add-Content -Path $tracePath -Encoding UTF8

    # Find the actual assistant message, skipping reasoning items.
    $messageItem = $response.output | Where-Object { $_.type -eq "message" } | Select-Object -First 1

    if ($null -eq $messageItem) {
        throw "No assistant message item was found in the OpenAI response."
    }

    $textItem = $messageItem.content | Where-Object { $_.type -eq "output_text" } | Select-Object -First 1

    if ($null -eq $textItem) {
        throw "No output_text item was found in the assistant message."
    }

    $modelText = $textItem.text
    $modelText | Set-Content -Path "$debugFolder\debug_model_text_$safeFile.json" -Encoding UTF8

    $memeData = $modelText | ConvertFrom-Json

    # At this point embedded JSON escapes are already safe PowerShell strings.
    # Now strip quotes/apostrophes from the VALUES before PAD, EXIF, SQL, or filenames see them.
    $memeData = Sanitize-MemeDataStrings $memeData
    $safeFileName = Remove-QuoteChars $originalName
    $safeVersion = Remove-QuoteChars $version

    # Insert OCR text into the final JSON.
    # OCR was not sent to GPT. It is only attached here for JSON, SQL, EXIF, and filename logic.
    if ($memeData.PSObject.Properties.Name -contains "visible_text") {
        $memeData.visible_text = $safeOcrClean
    }
    else {
        $memeData | Add-Member -NotePropertyName "visible_text" -NotePropertyValue $safeOcrClean
    }
	
	$memeData | Add-Member -NotePropertyName "sort_version" -NotePropertyValue $safeVersion -Force
	$memeData | Add-Member -NotePropertyName "processed_at" -NotePropertyValue $processedAt -Force
	$memeData | Add-Member -NotePropertyName "original_file" -NotePropertyValue $safeFileName -Force
	$memeData | Add-Member -NotePropertyName "original_hash" -NotePropertyValue $originalHash -Force
	$memeData | Add-Member -NotePropertyName "normal_hash" -NotePropertyValue $normalHash -Force

    $finalJson = $memeData | ConvertTo-Json -Depth 20 -Compress

    # Prove the final JSON is valid before sending it back to PAD.
    try {
        $finalJson | ConvertFrom-Json | Out-Null
    }
    catch {
        $finalJson | Set-Content -Path "$debugFolder\debug_invalid_final_json_$safeFile.json" -Encoding UTF8
        throw
    }

    $finalJson | Set-Content -Path "$debugFolder\debug_final_json_$safeFile.json" -Encoding UTF8

    [Console]::Out.Write($finalJson)
}
catch {
    $err = $_ | Out-String

    try {
        $err | Add-Content -Path $tracePath -Encoding UTF8
    }
    catch {
        # If the debug write itself fails, still surface the original error to PAD.
    }

    throw
}

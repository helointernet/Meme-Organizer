param(
    [string]$md5Hash,
    [string]$processedAt,
    [string]$ocrClean,
    [string]$fileName,
    [string]$version,
    [string]$debugFolder,
    [string]$imagePath,
    [string]$mimeType,
	[string]$safeFile
)

$ErrorActionPreference = "Stop"

# Dummy GPT script for Meme Organizer.
# Same parameter list and same stdout behavior as gpt_1.0.ps1,
# but it never calls OpenAI and never spends tokens.

$tracePath = "$debugFolder\debug_powershell_trace_$safeFile.txt"
$responsePath = "$debugFolder\debug_full_response_$safeFile.json"
$modelTextPath = "$debugFolder\debug_model_text_$safeFile.json"
$finalJsonPath = "$debugFolder\debug_final_json_$safeFile.json"

try {
    if ([string]::IsNullOrWhiteSpace($debugFolder)) {
        throw "debugFolder was blank."
    }

    if (-not (Test-Path -LiteralPath $debugFolder)) {
        New-Item -ItemType Directory -LiteralPath $debugFolder -Force | Out-Null
    }

    "START DUMMY GPT SCRIPT" | Set-Content -LiteralPath $tracePath -Encoding UTF8
    "No API key checked." | Add-Content -LiteralPath $tracePath -Encoding UTF8
    "No OpenAI request sent." | Add-Content -LiteralPath $tracePath -Encoding UTF8
    "Image path: $imagePath" | Add-Content -LiteralPath $tracePath -Encoding UTF8
    "MIME type: $mimeType" | Add-Content -LiteralPath $tracePath -Encoding UTF8

    if ([string]::IsNullOrWhiteSpace($processedAt)) {
        $processedAt = (Get-Date).ToString("s")
        "processedAt was blank; generated timestamp: $processedAt" | Add-Content -LiteralPath $tracePath -Encoding UTF8
    }

    if ([string]::IsNullOrWhiteSpace($safeFile)) {
        if (-not [string]::IsNullOrWhiteSpace($imagePath)) {
            $safeFile = [System.IO.Path]::GetFileName($imagePath)
            "safeFile was blank; derived from imagePath: $safeFile" | Add-Content -LiteralPath $tracePath -Encoding UTF8
        }
        else {
            $safeFile = "unknown_file"
            "safeFile and imagePath were blank; using unknown_file." | Add-Content -LiteralPath $tracePath -Encoding UTF8
        }
    }

    # Keep the dummy data intentionally boring and stable.
    # The visible_text field still receives the real cleaned OCR from PAD.
    $memeData = [ordered]@{
        summary      = "DUMMY SUMMARY - placeholder generated without calling GPT."
        category     = "Uncategorized"
        confidence   = 0.01
        subjects     = @("dummy subject", "test image", "placeholder")
        tags         = @("dummy", "test", "placeholder", "no api call")
        visible_text = $ocrClean
        processed_at = $processedAt
        original_file = $fileName
        file_hash    = $md5Hash
        sort_version = $version
    }

    $modelOnlyData = [ordered]@{
        summary    = $memeData.summary
        category   = $memeData.category
        confidence = $memeData.confidence
        subjects   = $memeData.subjects
        tags       = $memeData.tags
    }

    $modelText = $modelOnlyData | ConvertTo-Json -Depth 20 -Compress
    $modelText | Set-Content -LiteralPath $modelTextPath -Encoding UTF8

    $fakeResponse = [ordered]@{
        id = "dummy_no_api_call"
        object = "dummy_response"
        created_at = [DateTimeOffset]::Now.ToUnixTimeSeconds()
        status = "completed"
        model = "dummy-local-placeholder"
        output = @(
            [ordered]@{
                type = "message"
                status = "completed"
                content = @(
                    [ordered]@{
                        type = "output_text"
                        text = $modelText
                    }
                )
            }
        )
        usage = [ordered]@{
            input_tokens = 0
            output_tokens = 0
            total_tokens = 0
        }
    }

    $fakeResponse | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $responsePath -Encoding UTF8
    "Dummy full response written." | Add-Content -LiteralPath $tracePath -Encoding UTF8

	# Find the actual assistant message, skipping reasoning items.
	$messageItem = $fakeResponse.output | Where-Object { $_.type -eq "message" } | Select-Object -First 1

	if ($null -eq $messageItem) {
		throw "No message item found in response output."
	}

	$textItem = $messageItem.content | Where-Object { $_.type -eq "output_text" } | Select-Object -First 1

	if ($null -eq $textItem) {
		throw "No output_text item found in message content."
	}

	$modelText = $textItem.text
	$modelText | Set-Content -LiteralPath "$debugFolder\debug_model_text_$safeFile.json" -Encoding UTF8

	if ([string]::IsNullOrWhiteSpace($modelText)) {
		throw "Model output text was blank."
	}
	
# Split here

	$memeData = $modelText | ConvertFrom-Json

	# Insert OCR text into the final JSON.
	# If visible_text already exists for some reason, overwrite it.
	if ($memeData.PSObject.Properties.Name -contains "visible_text") {
	    $memeData.visible_text = $ocrClean
	}
	else {
	    $memeData | Add-Member -NotePropertyName "visible_text" -NotePropertyValue $ocrClean
	}
	
	$memeData | Add-Member -NotePropertyName "processed_at" -NotePropertyValue $processedAt -Force
	$memeData | Add-Member -NotePropertyName "original_file" -NotePropertyValue $fileName -Force
	$memeData | Add-Member -NotePropertyName "file_hash" -NotePropertyValue $md5Hash -Force
	$memeData | Add-Member -NotePropertyName "sort_version" -NotePropertyValue $version -Force

    $finalJson = $memeData | ConvertTo-Json -Depth 20 -Compress

    # Prove the final JSON is valid before sending it back to PAD.
    try {
        $finalJson | ConvertFrom-Json | Out-Null
    }
    catch {
        $finalJson | Set-Content -LiteralPath ("$debugFolder\debug_invalid_final_json_$safeFile.json") -Encoding UTF8
        throw "Final JSON failed validation before returning to PAD."
    }

    $finalJson | Set-Content -LiteralPath $finalJsonPath -Encoding UTF8
    "Dummy final JSON written." | Add-Content -LiteralPath $tracePath -Encoding UTF8

    # IMPORTANT: stdout must contain only the JSON, because PAD captures this.
    [Console]::Out.Write($finalJson)
}
catch {
    try {
        if (-not [string]::IsNullOrWhiteSpace($debugFolder)) {
            if (-not (Test-Path -LiteralPath $debugFolder)) {
                New-Item -ItemType Directory -LiteralPath $debugFolder -Force | Out-Null
            }

            "ERROR" | Add-Content -LiteralPath $tracePath -Encoding UTF8
            $_.Exception.Message | Add-Content -LiteralPath $tracePath -Encoding UTF8
            $_.ScriptStackTrace | Add-Content -LiteralPath $tracePath -Encoding UTF8
        }
    }
    catch {
        # Do not write debug failure details to stdout.
    }

    # Match the real GPT script behavior: blank stdout means failure to PAD.
    [Console]::Out.Write("")
}

param(
    [string]$source
)
$ErrorActionPreference = "Stop"
$output = "unknown"

$bytes = [System.IO.File]::ReadAllBytes($source)

# JPG / JPEG: FF D8 FF
if ($bytes[0] -eq 0xFF -and $bytes[1] -eq 0xD8 -and $bytes[2] -eq 0xFF) {
	$output = ".jpg"
}

# PNG: 89 50 4E 47 0D 0A 1A 0A
if (
	$bytes[0] -eq 0x89 -and
	$bytes[1] -eq 0x50 -and
	$bytes[2] -eq 0x4E -and
	$bytes[3] -eq 0x47 -and
	$bytes[4] -eq 0x0D -and
	$bytes[5] -eq 0x0A -and
	$bytes[6] -eq 0x1A -and
	$bytes[7] -eq 0x0A
) {
	$output = ".png"
}

# GIF: GIF87a or GIF89a
$first6 = [System.Text.Encoding]::ASCII.GetString($bytes, 0, 6)
if ($first6 -eq "GIF87a" -or $first6 -eq "GIF89a") {
	$output = ".gif"
}

# WebP: RIFF....WEBP
$riff = [System.Text.Encoding]::ASCII.GetString($bytes, 0, 4)
$webp = [System.Text.Encoding]::ASCII.GetString($bytes, 8, 4)

if ($riff -eq "RIFF" -and $webp -eq "WEBP") {
	$output = ".webp"
}

# BMP: BM
if ($bytes[0] -eq 0x42 -and $bytes[1] -eq 0x4D) {
	$output = ".bmp"
}

# TIFF: II*00 or MM00*
if (
	($bytes[0] -eq 0x49 -and $bytes[1] -eq 0x49 -and $bytes[2] -eq 0x2A -and $bytes[3] -eq 0x00) -or
	($bytes[0] -eq 0x4D -and $bytes[1] -eq 0x4D -and $bytes[2] -eq 0x00 -and $bytes[3] -eq 0x2A)
) {
	$output = ".tiff"
}

# WebM: EBML header + DocType "webm" somewhere near the start
# EBML header: 1A 45 DF A3
if (
	$bytes.Length -ge 16 -and
	$bytes[0] -eq 0x1A -and
	$bytes[1] -eq 0x45 -and
	$bytes[2] -eq 0xDF -and
	$bytes[3] -eq 0xA3
) {
	$scanLength = [Math]::Min($bytes.Length, 4096)
	$headerText = [System.Text.Encoding]::ASCII.GetString($bytes, 0, $scanLength)

	if ($headerText -match "webm") {
		$output = ".webm"
	}
}

# MP4 / ISO Base Media: usually has "ftyp" at byte offset 4
if ($bytes.Length -ge 12) {
    $boxType = [System.Text.Encoding]::ASCII.GetString($bytes, 4, 4)

    if ($boxType -eq "ftyp") {
        $majorBrand = [System.Text.Encoding]::ASCII.GetString($bytes, 8, 4).ToLowerInvariant()

        $mp4Brands = @(
            "isom",
            "iso2",
            "iso4",
            "iso5",
            "iso6",
            "mp41",
            "mp42",
            "m4v ",
            "avc1",
            "dash",
            "msnv"
        )

        if ($mp4Brands -contains $majorBrand) {
            $output = ".mp4"
        }
    }
}

# AVIF: ISO BMFF container, "ftyp" at byte offset 4, AVIF brand nearby
if ($bytes.Length -ge 16) {
    $boxType = [System.Text.Encoding]::ASCII.GetString($bytes, 4, 4)

    if ($boxType -eq "ftyp") {
        $scanLength = [Math]::Min($bytes.Length, 64)
        $brandText = [System.Text.Encoding]::ASCII.GetString($bytes, 0, $scanLength).ToLowerInvariant()

        if ($brandText -match "avif" -or $brandText -match "avis") {
            $output = ".avif"
        }
    }
}

# HEIC / HEIF: ISO BMFF container, "ftyp" at byte offset 4, HEIF-family brand nearby
if ($bytes.Length -ge 16) {
    $boxType = [System.Text.Encoding]::ASCII.GetString($bytes, 4, 4)

    if ($boxType -eq "ftyp") {
        $scanLength = [Math]::Min($bytes.Length, 64)
        $brandText = [System.Text.Encoding]::ASCII.GetString($bytes, 0, $scanLength).ToLowerInvariant()

        if (
            $brandText -match "heic" -or
            $brandText -match "heix" -or
            $brandText -match "hevc" -or
            $brandText -match "hevx" -or
            $brandText -match "mif1" -or
            $brandText -match "msf1"
        ) {
            $output = ".heic"
        }
    }
}

# JPEG XL codestream: FF 0A
if (
    $bytes.Length -ge 2 -and
    $bytes[0] -eq 0xFF -and
    $bytes[1] -eq 0x0A
) {
    $output = ".jxl"
    exit 0
}

# JPEG XL container: 00 00 00 0C 4A 58 4C 20 0D 0A 87 0A
if (
    $bytes.Length -ge 12 -and
    $bytes[0] -eq 0x00 -and
    $bytes[1] -eq 0x00 -and
    $bytes[2] -eq 0x00 -and
    $bytes[3] -eq 0x0C -and
    $bytes[4] -eq 0x4A -and
    $bytes[5] -eq 0x58 -and
    $bytes[6] -eq 0x4C -and
    $bytes[7] -eq 0x20
) {
    $output = ".jxl"
    exit 0
}

[Console]::Out.Write($output)
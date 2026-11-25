param(
    [string]$currentMeme,
	[string]$normalMeme,
	[string]$realExtension,
	[string]$ocrClean
)
$ErrorActionPreference = "Stop"

$folder = [System.IO.Path]::GetDirectoryName($currentMeme)
$stem = [System.IO.Path]::GetFileNameWithoutExtension($currentMeme)
$dest = $currentMeme
$convertJPG = $true

$opaque = magick identify -format "%[opaque]" "$normalMeme"
$colors = magick identify -format "%k" "$normalMeme"
$edges = magick "$normalMeme" -colorspace Gray -canny 0x1+10%+30% -format "%[fx:mean]" info:

if ($realExtension -eq ".png" -or
	$realExtension -eq ".jpg"
) {
	[Console]::Out.Write($dest)
	exit
}

if ([int]$colors -lt 60000 -and $edges -lt 0.06) {
	$convertJPG = $false
}

if (-not [string]::IsNullOrWhiteSpace($ocrClean) -and
	$ocrClean.Length -gt 3
) {
	$convertJPG = $true
}

if ($opaque -eq $false) {
	$convertJPG = $false
}

if ($convertJPG -eq $true) {
	$dest = [System.IO.Path]::Combine($folder, "$stem.jpg")
	& magick "$currentMeme" -quality 100 -sampling-factor 1x1 "$dest"
	Remove-Item $currentMeme -Force
} else {
	$dest = [System.IO.Path]::Combine($folder, "$stem.png")
	& magick "$currentMeme" -quality 100 -sampling-factor 1x1 "$dest"
	Remove-Item $currentMeme -Force
}

[Console]::Out.Write($dest)
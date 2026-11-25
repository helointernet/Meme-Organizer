param(
    [string]$source,
	[string]$exifTool,
	[string]$hashScript
)
$ErrorActionPreference = "Stop"

$ext = [System.IO.Path]::GetExtension($source).ToLowerInvariant()
$folder = [System.IO.Path]::GetDirectoryName($source)
$stem = [System.IO.Path]::GetFileNameWithoutExtension($source)

# Convert to PNG if not
if ($ext -ne ".png") {
	$dest = [System.IO.Path]::Combine($folder, "$stem.png")
    & magick "$source" -quality 100 -sampling-factor 1x1 "$dest"
	Remove-Item $source -Force
	$source = $dest
}

# Strip data
$exifArgs = @(
	"-all=",
	"-overwrite_original",
	"-q",
	"-q"
)
$exifArgs += $source
& $exifTool @exifArgs

# Resize
$normal = [System.IO.Path]::Combine($folder, "$stem`_normal.png")
& magick "$source" -resize 512x512 "$normal"

# Get hash
$hash = & $hashScript -source $normal

[Console]::Out.Write($hash)
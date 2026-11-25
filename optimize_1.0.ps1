param(
    [string]$source
)
$ErrorActionPreference = "Stop"

$folder = [System.IO.Path]::GetDirectoryName($source)
$stem = [System.IO.Path]::GetFileNameWithoutExtension($source)
$ext = [System.IO.Path]::GetExtension($source).ToLowerInvariant()
$dest = [System.IO.Path]::Combine($folder, "$stem`_OCR$ext")

magick "$source" `
	-auto-orient `
	-colorspace Gray `
	-contrast-stretch 1%x1% `
	-despeckle `
	-enhance `
	-sharpen 0x1 `
	-strip `
	"$dest"
  
[Console]::Out.Write($dest)
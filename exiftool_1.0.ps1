param(
	[string]$json,
	[string]$exifTool,
	[string]$filePath,
	[string]$date
)
$ErrorActionPreference = "Stop"

$data = $json | ConvertFrom-Json

$summary = $data.summary
$visible_text = $data.visible_text
$subjects = $data.subjects
$subjectString = $subjects -join ";"
$tags = $data.tags
$tagString = $tags -join ";"

$exifArgs = @(
	"-all=",
	"--ICC_Profile:all",
	"-overwrite_original",
	"-latin",
	"-m",
	"-v2",

	"-Title=$summary",
	"-XPTitle=$summary",
	"-Description=$summary",

	"-Subject=$subjectString",
	"-XPSubject=$subjectString",

	"-Keywords=$tagString",
	"-XPKeywords=$tagString",

	"-XMP-microsoft:DateAcquired=$date"
)

foreach ($subject in $subjects) {
    $exifArgs += "-XMP-dc:Subject+=$subject"
}

foreach ($tag in $tags) {
    $exifArgs += "-XMP-dc:Subject+=$tag"
}

if (-not [string]::IsNullOrWhiteSpace($visible_text)) {
	$exifArgs += "-Comment=$visible_text"
	$exifArgs += "-XPComment=$visible_text"
	$exifArgs += "-UserComment=$visible_text"
	$exifArgs += "-XMP-dc:Description=$visible_text"
	$exifArgs += "-IPTC:Caption-Abstract=$visible_text"
	$exifArgs += "-PNG:Comment=$visible_text"
	$exifArgs += "-PNG:Description=$visible_text"
}

$exifArgs += $filePath

& $exifTool @exifArgs
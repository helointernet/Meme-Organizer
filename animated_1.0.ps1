param(
    [string]$source
)
$ErrorActionPreference = "Stop"

$ext = [System.IO.Path]::GetExtension($source).ToLowerInvariant()

# WEBM is always routed away from OpenAI.
if ($ext -eq ".webm") {
    [Console]::Out.Write("true")
    exit
}

if ($ext -eq ".mp4") {
    [Console]::Out.Write("true")
    exit
}

# Only GIF needs animation detection.
if ($ext -ne ".gif") {
    [Console]::Out.Write("false")
    exit
}

try {
    Add-Type -AssemblyName System.Drawing

    $image = [System.Drawing.Image]::FromFile($source)

    try {
        $frameCount = $image.GetFrameCount([System.Drawing.Imaging.FrameDimension]::Time)

        if ($frameCount -gt 1) {
            [Console]::Out.Write("true")
        }
        else {
            [Console]::Out.Write("false")
        }
    }
    finally {
        $image.Dispose()
    }
}
catch {
    # If GIF frame detection fails, route it away from OpenAI to be safe.
    [Console]::Out.Write("true")
}
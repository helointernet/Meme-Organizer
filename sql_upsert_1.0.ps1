param(
    [string]$sqlite,
    [string]$dbPath,
	[string]$imagePath,
	[string]$metadataPath,
	[string]$json,
	[string]$fileName,
	[string]$debugFolder,
	[string]$safeFile
)
$ErrorActionPreference = "Stop"

$data = $json | ConvertFrom-Json

$currentFile = [System.IO.Path]::GetFileName($imagePath)

$category = [string]$data.category
$summary = [string]$data.summary
$visibleText = [string]$data.visible_text
$confidence = [double]$data.confidence
$originalFile = [string]$data.original_file
$processedAt = [string]$data.processed_at
$sortVersion = [string]$data.sort_version
$originalHash = [string]$data.original_hash
$normalHash = [string]$data.normal_hash
$processedHash = [string]$data.processed_hash

$subjects = @($data.subjects)
$tags = @($data.tags)

$subjectsText = $subjects -join "; "
$tagsText = $tags -join "; "
$searchText = "$category $summary $visibleText $subjectsText $tagsText"

function SqlQuote($value) {
    if ($null -eq $value) {
        return "NULL"
    }

    $text = [string]$value
    $text = $text -replace "'", "''"
    return "'$text'"
}

function SqlNumber($value) {
    if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) {
        return "NULL"
    }

    return ([string]$value)
}

$hashSql = SqlQuote $normalHash

$schemaSql = @"
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS memes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    original_hash TEXT NOT NULL UNIQUE,
	normal_hash TEXT NOT NULL UNIQUE,
	processed_hash TEXT NOT NULL UNIQUE,
    original_file TEXT,
    current_file TEXT NOT NULL,
    current_path TEXT NOT NULL,
    metadata_path TEXT,
    category TEXT NOT NULL,
    summary TEXT,
    visible_text TEXT,
    subjects_text TEXT,
    tags_text TEXT,
    search_text TEXT,
    confidence REAL,
    processed_at TEXT,
    sort_version TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS meme_subjects (
    meme_id INTEGER NOT NULL,
    subject TEXT NOT NULL,
    PRIMARY KEY (meme_id, subject),
    FOREIGN KEY (meme_id) REFERENCES memes(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS meme_tags (
    meme_id INTEGER NOT NULL,
    tag TEXT NOT NULL,
    PRIMARY KEY (meme_id, tag),
    FOREIGN KEY (meme_id) REFERENCES memes(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_memes_category ON memes(category);
CREATE INDEX IF NOT EXISTS idx_memes_hash ON memes(normal_hash);
CREATE INDEX IF NOT EXISTS idx_subjects_subject ON meme_subjects(subject);
CREATE INDEX IF NOT EXISTS idx_tags_tag ON meme_tags(tag);
"@

$upsertSql = @"
BEGIN TRANSACTION;

INSERT INTO memes (
    original_hash,
	normal_hash,
	processed_hash,
    original_file,
    current_file,
    current_path,
    metadata_path,
    category,
    summary,
    visible_text,
    subjects_text,
    tags_text,
    search_text,
    confidence,
    processed_at,
    sort_version
)
VALUES (
    $(SqlQuote $originalHash),
	$(SqlQuote $normalHash),
	$(SqlQuote $processedHash),
    $(SqlQuote $originalFile),
    $(SqlQuote $currentFile),
    $(SqlQuote $imagePath),
    $(SqlQuote $metadataPath),
    $(SqlQuote $category),
    $(SqlQuote $summary),
    $(SqlQuote $visibleText),
    $(SqlQuote $subjectsText),
    $(SqlQuote $tagsText),
    $(SqlQuote $searchText),
    $(SqlNumber $confidence),
    $(SqlQuote $processedAt),
    $(SqlQuote $sortVersion)
)
ON CONFLICT(normal_hash) DO UPDATE SET
	original_hash = excluded.original_hash,
	processed_hash = excluded.processed_hash,
    original_file = excluded.original_file,
    current_file = excluded.current_file,
    current_path = excluded.current_path,
    metadata_path = excluded.metadata_path,
    category = excluded.category,
    summary = excluded.summary,
    visible_text = excluded.visible_text,
    subjects_text = excluded.subjects_text,
    tags_text = excluded.tags_text,
    search_text = excluded.search_text,
    confidence = excluded.confidence,
    processed_at = excluded.processed_at,
    sort_version = excluded.sort_version,
    updated_at = CURRENT_TIMESTAMP;

DELETE FROM meme_subjects
WHERE meme_id = (SELECT id FROM memes WHERE normal_hash = $hashSql);

DELETE FROM meme_tags
WHERE meme_id = (SELECT id FROM memes WHERE normal_hash = $hashSql);
"@

$subjectSql = ""
foreach ($subject in $subjects) {
    if (-not [string]::IsNullOrWhiteSpace([string]$subject)) {
        $subjectSql += "INSERT OR IGNORE INTO meme_subjects (meme_id, subject) SELECT id, $(SqlQuote $subject) FROM memes WHERE normal_hash = $hashSql;`n"
    }
}

$tagSql = ""
foreach ($tag in $tags) {
    if (-not [string]::IsNullOrWhiteSpace([string]$tag)) {
        $tagSql += "INSERT OR IGNORE INTO meme_tags (meme_id, tag) SELECT id, $(SqlQuote $tag) FROM memes WHERE normal_hash = $hashSql;`n"
    }
}

$finalSql = $schemaSql + "`n" + $upsertSql + "`n" + $subjectSql + "`n" + $tagSql + "`nCOMMIT;"

$sqlPath = "$debugFolder\sqlite_upsert_$safeFile.sql"
$finalSql | Set-Content -LiteralPath $sqlPath -Encoding UTF8

$output = Get-Content -LiteralPath $sqlPath -Raw -Encoding UTF8 | & $sqlite $dbPath 2>&1

if ($LASTEXITCODE -ne 0) {
    $output | Set-Content -LiteralPath "$debugFolder\sqlite_error_$safeFile.txt" -Encoding UTF8
    throw "SQLite insert failed. See sqlite_error log."
}

[Console]::Out.Write("SQLite OK")
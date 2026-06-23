param(
  [ValidateSet("debug", "profile", "release")]
  [string]$Configuration = "release",
  [string]$OutputDir = ".\artifacts\linux-portable"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$bundleMap = @{
  "debug" = "build\linux\x64\debug\bundle"
  "profile" = "build\linux\x64\profile\bundle"
  "release" = "build\linux\x64\release\bundle"
}

$sourceDir = Join-Path $projectRoot $bundleMap[$Configuration]

if (-not (Test-Path $sourceDir)) {
  throw "Linux bundle not found at $sourceDir. Run a Linux build first."
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$zipName = "StudyDesk-linux-portable-$Configuration-$timestamp.zip"
$zipPath = Join-Path $OutputDir $zipName

if (Test-Path $zipPath) {
  Remove-Item -LiteralPath $zipPath -Force
}

Compress-Archive -Path (Join-Path $sourceDir '*') -DestinationPath $zipPath -CompressionLevel Optimal

Write-Host "Linux portable bundle created:"
Write-Host $zipPath

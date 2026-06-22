param(
  [ValidateSet("Debug", "Release", "Profile")]
  [string]$Configuration = "Release",
  [string]$OutputDir = ".\artifacts\windows-portable"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceDir = Join-Path $projectRoot "build\windows\x64\runner\$Configuration"

if (-not (Test-Path $sourceDir)) {
  throw "Build output not found at $sourceDir. Run a Windows build first."
}

$exeCandidates = @(
  (Join-Path $sourceDir "StudyDesk.exe"),
  (Join-Path $sourceDir "flutter_app.exe")
)

$exePath = $exeCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $exePath) {
  throw "No Windows executable was found in $sourceDir."
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$zipName = "StudyDesk-windows-portable-$Configuration-$timestamp.zip"
$zipPath = Join-Path $OutputDir $zipName

if (Test-Path $zipPath) {
  Remove-Item -LiteralPath $zipPath -Force
}

Compress-Archive -Path (Join-Path $sourceDir '*') -DestinationPath $zipPath -CompressionLevel Optimal

Write-Host "Portable bundle created:"
Write-Host $zipPath

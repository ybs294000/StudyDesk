param(
  [ValidateSet("debug", "profile", "release")]
  [string]$Configuration = "release",
  [string]$OutputDir = ".\artifacts\android-apk"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

$apkMap = @{
  "debug" = "build\app\outputs\flutter-apk\app-debug.apk"
  "profile" = "build\app\outputs\flutter-apk\app-profile.apk"
  "release" = "build\app\outputs\flutter-apk\app-release.apk"
}

$sourceApk = Join-Path $projectRoot $apkMap[$Configuration]

if (-not (Test-Path $sourceApk)) {
  throw "APK output not found at $sourceApk. Run an Android build first."
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$apkName = "StudyDesk-android-$Configuration-$timestamp.apk"
$destinationApk = Join-Path $OutputDir $apkName

Copy-Item -LiteralPath $sourceApk -Destination $destinationApk -Force

Write-Host "Packaged APK created:"
Write-Host $destinationApk

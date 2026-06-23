param(
  [ValidateSet("debug", "profile", "release")]
  [string]$Configuration = "release"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $projectRoot

function Remove-StaleFlutterAndroidArtifacts {
  param(
    [string]$ProjectRoot
  )

  $pathsToReset = @(
    (Join-Path $ProjectRoot "build\app\intermediates"),
    (Join-Path $ProjectRoot "build\app\outputs\flutter-apk")
  )

  foreach ($path in $pathsToReset) {
    if (Test-Path $path) {
      Write-Host "Resetting stale Flutter Android artifacts: $path"
      Remove-Item -LiteralPath $path -Recurse -Force
    }
  }
}

Write-Host "Building StudyDesk for Android ($Configuration)..."
Remove-StaleFlutterAndroidArtifacts -ProjectRoot $projectRoot

switch ($Configuration) {
  "debug" { & flutter build apk --debug }
  "profile" { & flutter build apk --profile }
  default { & flutter build apk }
}

if ($LASTEXITCODE -ne 0) {
  throw "Android build failed with exit code $LASTEXITCODE. APK packaging was skipped so no stale artifact is produced."
}

Write-Host "Packaging APK into artifacts..."
& (Join-Path $projectRoot "package_android_apk.ps1") -Configuration $Configuration

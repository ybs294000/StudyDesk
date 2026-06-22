param(
  [ValidateSet("Debug", "Release", "Profile")]
  [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $projectRoot

function Remove-StaleFlutterWindowsArtifacts {
  param(
    [string]$ProjectRoot
  )

  $pathsToReset = @(
    (Join-Path $ProjectRoot "windows\flutter\ephemeral\.plugin_symlinks"),
    (Join-Path $ProjectRoot "build\windows\x64\plugins")
  )

  foreach ($path in $pathsToReset) {
    if (Test-Path $path) {
      Write-Host "Resetting stale Flutter build artifacts: $path"
      Remove-Item -LiteralPath $path -Recurse -Force
    }
  }
}

Write-Host "Building StudyDesk for Windows ($Configuration)..."
Remove-StaleFlutterWindowsArtifacts -ProjectRoot $projectRoot

switch ($Configuration) {
  "Debug" { & flutter build windows --debug }
  "Profile" { & flutter build windows --profile }
  default { & flutter build windows }
}

if ($LASTEXITCODE -ne 0) {
  throw "Windows build failed with exit code $LASTEXITCODE. Portable packaging was skipped so no stale zip is produced."
}

Write-Host "Packaging portable zip..."
& (Join-Path $projectRoot "package_windows_portable.ps1") -Configuration $Configuration

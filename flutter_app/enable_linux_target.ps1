param()

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $projectRoot

Write-Host "Enabling Flutter Linux desktop support..."
& flutter config --enable-linux-desktop
if ($LASTEXITCODE -ne 0) {
  throw "flutter config failed with exit code $LASTEXITCODE"
}

Write-Host "Generating Linux desktop project files..."
& flutter create --platforms=linux .
if ($LASTEXITCODE -ne 0) {
  throw "flutter create for Linux failed with exit code $LASTEXITCODE"
}

Write-Host "Linux desktop target files generated in .\\linux"

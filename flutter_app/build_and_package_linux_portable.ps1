param(
  [ValidateSet("debug", "profile", "release")]
  [string]$Configuration = "release",
  [string]$Distro = "Ubuntu-24.04"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $projectRoot

function Convert-ToWslPath {
  param([string]$WindowsPath)
  $normalized = $WindowsPath -replace '\\', '/'
  if ($normalized -match '^([A-Za-z]):/(.*)$') {
    $drive = $matches[1].ToLower()
    $rest = $matches[2]
    return "/mnt/$drive/$rest"
  }
  throw "Could not convert path to WSL format: $WindowsPath"
}

function Test-WslAvailable {
  try {
    $null = & wsl -l -q
    return $true
  } catch {
    return $false
  }
}

if (-not (Test-WslAvailable)) {
  throw "WSL is not available on this machine. To build Linux from this Windows PC, install WSL2 with Ubuntu first."
}

$linuxFolder = Join-Path $projectRoot "linux"
if (-not (Test-Path $linuxFolder)) {
  throw "Linux target files are missing. Run .\enable_linux_target.ps1 first after setting up Flutter in Linux."
}

$wslProjectRoot = Convert-ToWslPath $projectRoot
$configArg = switch ($Configuration) {
  "debug" { "--debug" }
  "profile" { "--profile" }
  default { "--release" }
}

$buildCommand = @"
set -e
cd '$wslProjectRoot'
if ! command -v flutter >/dev/null 2>&1; then
  echo 'Flutter is not installed inside WSL.'
  exit 2
fi
flutter config --enable-linux-desktop
flutter pub get
flutter build linux $configArg
"@

Write-Host "Building StudyDesk for Linux ($Configuration) inside WSL distro '$Distro'..."
& wsl -d $Distro bash -lc $buildCommand

if ($LASTEXITCODE -ne 0) {
  throw "Linux build failed with exit code $LASTEXITCODE. Packaging was skipped."
}

Write-Host "Packaging Linux bundle into artifacts..."
& (Join-Path $projectRoot "package_linux_portable.ps1") -Configuration $Configuration

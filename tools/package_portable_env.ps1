param(
  [string]$SourceDevEnv = "D:\V881\padtest\dev_env",
  [string]$SourceFlutter = "G:\flutter",
  [string]$OutputDir = "",
  [switch]$Zip
)

$ErrorActionPreference = "Stop"

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if (-not $OutputDir) {
  $OutputDir = Join-Path $ProjectRoot "portable_build_env"
}

$OutputDir = [System.IO.Path]::GetFullPath($OutputDir)
$TargetDevEnv = Join-Path $OutputDir "dev_env"

if (-not (Test-Path -LiteralPath $SourceDevEnv -PathType Container)) {
  throw "Source dev_env not found: $SourceDevEnv"
}
if (-not (Test-Path -LiteralPath $SourceFlutter -PathType Container)) {
  throw "Source Flutter SDK not found: $SourceFlutter"
}

New-Item -ItemType Directory -Force -Path $TargetDevEnv | Out-Null

function Copy-Dir {
  param(
    [string]$From,
    [string]$To,
    [string[]]$Exclude = @()
  )
  Write-Host "Copying $From -> $To"
  New-Item -ItemType Directory -Force -Path $To | Out-Null
  $excludeArgs = @()
  if ($Exclude.Count -gt 0) {
    $excludeArgs += "/XD"
    $excludeArgs += $Exclude
  }
  robocopy $From $To /MIR /R:2 /W:2 /NFL /NDL /NP @excludeArgs
  if ($LASTEXITCODE -ge 8) {
    throw "robocopy failed with exit code $LASTEXITCODE"
  }
}

Copy-Dir (Join-Path $SourceDevEnv "jdk-17.0.13+11") (Join-Path $TargetDevEnv "jdk-17.0.13+11")
Copy-Dir (Join-Path $SourceDevEnv "android-sdk") (Join-Path $TargetDevEnv "android-sdk") @(".temp")
Copy-Dir $SourceFlutter (Join-Path $TargetDevEnv "flutter") @(".git", ".pub-cache")

$readme = @"
# Portable build environment

Copy this `dev_env` folder next to the project folder:

```
parent-folder/
  dev_env/
    android-sdk/
    flutter/
    jdk-17.0.13+11/
  ipad_boss_app/
```

Then build from the project folder:

```
powershell -ExecutionPolicy Bypass -File tools\build_apk.ps1
```

You can also keep `dev_env` inside the project root. It is ignored by Git on purpose.
"@
Set-Content -LiteralPath (Join-Path $OutputDir "README.md") -Value $readme -Encoding UTF8

if ($Zip) {
  $zipPath = Join-Path $ProjectRoot "portable_build_env.zip"
  if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
  Compress-Archive -Path (Join-Path $OutputDir "*") -DestinationPath $zipPath -Force
  Write-Host "Portable environment zip: $zipPath" -ForegroundColor Green
} else {
  Write-Host "Portable environment folder: $OutputDir" -ForegroundColor Green
}

param(
  [string]$SourceDevEnv = "",
  [string]$SourceFlutter = "",
  [string]$SourceJdk = "",
  [string]$SourceAndroidSdk = "",
  [string]$OutputDir = "",
  [switch]$AllowLargePackage,
  [switch]$Zip
)

$ErrorActionPreference = "Stop"

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if (-not $AllowLargePackage) {
  throw "This script copies the full SDK toolchain and can create an ~8GB package. Use BUILD_APK.md to download SDKs on the target machine, or pass -AllowLargePackage for offline distribution."
}

if (-not $OutputDir) {
  $OutputDir = Join-Path $ProjectRoot "portable_build_env"
}

$LocalConfig = Join-Path $PSScriptRoot "build_env.local.ps1"
if (Test-Path -LiteralPath $LocalConfig -PathType Leaf) {
  $LocalDevEnv = ""
  $LocalFlutterSdk = ""
  $LocalJdk = ""
  $LocalAndroidSdk = ""
  . $LocalConfig

  if (-not $SourceDevEnv -and $LocalDevEnv) { $SourceDevEnv = $LocalDevEnv }
  if (-not $SourceFlutter -and $LocalFlutterSdk) { $SourceFlutter = $LocalFlutterSdk }
  if (-not $SourceJdk -and $LocalJdk) { $SourceJdk = $LocalJdk }
  if (-not $SourceAndroidSdk -and $LocalAndroidSdk) { $SourceAndroidSdk = $LocalAndroidSdk }
}

$OutputDir = [System.IO.Path]::GetFullPath($OutputDir)
$TargetDevEnv = Join-Path $OutputDir "dev_env"

function Resolve-FirstExistingDir {
  param([string[]]$Candidates)
  foreach ($item in $Candidates) {
    if ($item -and (Test-Path -LiteralPath $item -PathType Container)) {
      return (Resolve-Path -LiteralPath $item).Path
    }
  }
  return $null
}

function Resolve-FlutterSdk {
  param([string[]]$Candidates)

  $resolved = Resolve-FirstExistingDir $Candidates
  if ($resolved) { return $resolved }

  $flutterCommand = Get-Command flutter.bat -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $flutterCommand) {
    $flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue | Select-Object -First 1
  }
  if ($flutterCommand -and $flutterCommand.Source) {
    $binDir = Split-Path -Parent $flutterCommand.Source
    $rootDir = Split-Path -Parent $binDir
    if (Test-Path -LiteralPath (Join-Path $rootDir "bin\flutter.bat")) {
      return (Resolve-Path -LiteralPath $rootDir).Path
    }
  }

  return $null
}

function Find-Jdk {
  param([string]$BaseDir)
  if ($SourceJdk -and (Test-Path -LiteralPath (Join-Path $SourceJdk "bin\java.exe"))) {
    return (Resolve-Path -LiteralPath $SourceJdk).Path
  }
  if ($env:JAVA_HOME -and (Test-Path -LiteralPath (Join-Path $env:JAVA_HOME "bin\java.exe"))) {
    return (Resolve-Path -LiteralPath $env:JAVA_HOME).Path
  }
  if ($BaseDir) {
    $jdk = Get-ChildItem -LiteralPath $BaseDir -Directory -Filter "jdk*" -ErrorAction SilentlyContinue |
      Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "bin\java.exe") } |
      Sort-Object Name |
      Select-Object -First 1
    if ($jdk) { return $jdk.FullName }
  }
  return $null
}

if (-not $SourceDevEnv) {
  $SourceDevEnv = Resolve-FirstExistingDir @(
    (Join-Path $ProjectRoot "dev_env"),
    (Join-Path $ProjectRoot "..\dev_env")
  )
} elseif (Test-Path -LiteralPath $SourceDevEnv -PathType Container) {
  $SourceDevEnv = (Resolve-Path -LiteralPath $SourceDevEnv).Path
}

$DevEnvFlutter = ""
if ($SourceDevEnv) { $DevEnvFlutter = Join-Path $SourceDevEnv "flutter" }

if (-not $SourceFlutter) {
  $SourceFlutter = Resolve-FlutterSdk @(
    $DevEnvFlutter,
    $env:FLUTTER_HOME
  )
} elseif (Test-Path -LiteralPath $SourceFlutter -PathType Container) {
  $SourceFlutter = (Resolve-Path -LiteralPath $SourceFlutter).Path
}

$SourceJdk = Find-Jdk $SourceDevEnv

$DevEnvAndroidSdk = ""
if ($SourceDevEnv) { $DevEnvAndroidSdk = Join-Path $SourceDevEnv "android-sdk" }
if (-not $SourceAndroidSdk) {
  $SourceAndroidSdk = Resolve-FirstExistingDir @(
    $DevEnvAndroidSdk,
    $env:ANDROID_HOME,
    $env:ANDROID_SDK_ROOT
  )
} elseif (Test-Path -LiteralPath $SourceAndroidSdk -PathType Container) {
  $SourceAndroidSdk = (Resolve-Path -LiteralPath $SourceAndroidSdk).Path
}

if (-not $SourceFlutter -or -not (Test-Path -LiteralPath (Join-Path $SourceFlutter "bin\flutter.bat"))) {
  throw "Source Flutter SDK not found. Put it in dev_env\flutter, set FLUTTER_HOME, or pass -SourceFlutter."
}
if (-not $SourceJdk -or -not (Test-Path -LiteralPath (Join-Path $SourceJdk "bin\java.exe"))) {
  throw "Source JDK not found. Put JDK 17 in dev_env, set JAVA_HOME, or pass -SourceJdk."
}
if (-not $SourceAndroidSdk -or -not (Test-Path -LiteralPath (Join-Path $SourceAndroidSdk "platforms\android-36\android.jar"))) {
  throw "Source Android SDK not found. Put it in dev_env\android-sdk, set ANDROID_HOME, or pass -SourceAndroidSdk."
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

Copy-Dir $SourceJdk (Join-Path $TargetDevEnv (Split-Path -Leaf $SourceJdk))
Copy-Dir $SourceAndroidSdk (Join-Path $TargetDevEnv "android-sdk") @(".temp")
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
powershell -ExecutionPolicy Bypass -File tools\build_apk.ps1 -SkipPubGet
```

You can also keep `dev_env` inside the project root. It is ignored by Git on purpose.

This package is large and intended only for offline distribution.
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

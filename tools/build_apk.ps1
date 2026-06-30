param(
  [string]$DevEnv = "",
  [string]$FlutterSdk = "",
  [switch]$SkipPubGet,
  [switch]$RunTests,
  [string[]]$ExtraFlutterArgs = @()
)

$ErrorActionPreference = "Stop"

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

function Resolve-FirstExistingDir {
  param([string[]]$Candidates)
  foreach ($item in $Candidates) {
    if ($item -and (Test-Path -LiteralPath $item -PathType Container)) {
      return (Resolve-Path -LiteralPath $item).Path
    }
  }
  return $null
}

function Find-Jdk {
  param([string]$BaseDir)
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

function To-PropertiesPath {
  param([string]$Path)
  return $Path.Replace("\", "/")
}

if (-not $DevEnv) {
  $DevEnv = Resolve-FirstExistingDir @(
    (Join-Path $ProjectRoot "dev_env"),
    (Join-Path $ProjectRoot "..\dev_env"),
    "D:\V881\padtest\dev_env"
  )
} elseif (Test-Path -LiteralPath $DevEnv -PathType Container) {
  $DevEnv = (Resolve-Path -LiteralPath $DevEnv).Path
}

$DevEnvFlutter = ""
if ($DevEnv) { $DevEnvFlutter = Join-Path $DevEnv "flutter" }

if (-not $FlutterSdk) {
  $FlutterSdk = Resolve-FirstExistingDir @(
    $DevEnvFlutter,
    $env:FLUTTER_HOME,
    "G:\flutter"
  )
} elseif (Test-Path -LiteralPath $FlutterSdk -PathType Container) {
  $FlutterSdk = (Resolve-Path -LiteralPath $FlutterSdk).Path
}

$Jdk = Find-Jdk $DevEnv
$DevEnvAndroidSdk = ""
if ($DevEnv) { $DevEnvAndroidSdk = Join-Path $DevEnv "android-sdk" }
$AndroidSdk = Resolve-FirstExistingDir @(
  $DevEnvAndroidSdk,
  $env:ANDROID_HOME,
  $env:ANDROID_SDK_ROOT
)

if (-not $FlutterSdk -or -not (Test-Path -LiteralPath (Join-Path $FlutterSdk "bin\flutter.bat"))) {
  throw "Flutter SDK not found. Put it in dev_env\flutter or pass -FlutterSdk."
}
if (-not $Jdk) {
  throw "JDK not found. Put JDK 17 in dev_env or set JAVA_HOME."
}
if (-not $AndroidSdk) {
  throw "Android SDK not found. Put it in dev_env\android-sdk or set ANDROID_HOME."
}

$env:JAVA_HOME = $Jdk
$env:ANDROID_HOME = $AndroidSdk
$env:ANDROID_SDK_ROOT = $AndroidSdk
$env:FLUTTER_HOME = $FlutterSdk
$env:Path = "$env:JAVA_HOME\bin;$env:ANDROID_HOME\platform-tools;$env:ANDROID_HOME\cmdline-tools\latest\bin;$env:FLUTTER_HOME\bin;$env:Path"

$localProperties = @(
  "sdk.dir=$(To-PropertiesPath $AndroidSdk)",
  "flutter.sdk=$(To-PropertiesPath $FlutterSdk)",
  "flutter.buildMode=release"
)
Set-Content -LiteralPath (Join-Path $ProjectRoot "android\local.properties") -Value $localProperties -Encoding ASCII

$Flutter = Join-Path $FlutterSdk "bin\flutter.bat"

Write-Host "Project:     $ProjectRoot"
Write-Host "Flutter SDK: $FlutterSdk"
Write-Host "JDK:         $Jdk"
Write-Host "Android SDK: $AndroidSdk"
Write-Host ""

Push-Location $ProjectRoot
try {
  & $Flutter --version

  if (-not $SkipPubGet) {
    & $Flutter pub get
  }

  if ($RunTests) {
    & $Flutter test
  }

  & $Flutter build apk --release @ExtraFlutterArgs

  $apk = Join-Path $ProjectRoot "build\app\outputs\flutter-apk\app-release.apk"
  if (-not (Test-Path -LiteralPath $apk)) {
    throw "APK was not found after build: $apk"
  }

  $hash = Get-FileHash -Algorithm SHA256 -LiteralPath $apk
  Write-Host ""
  Write-Host "APK built successfully:" -ForegroundColor Green
  Write-Host $apk
  Write-Host "SHA256: $($hash.Hash)"
}
finally {
  Pop-Location
}

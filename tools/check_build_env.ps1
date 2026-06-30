param(
  [string]$DevEnv = "",
  [string]$FlutterSdk = ""
)

$ErrorActionPreference = "Stop"

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$HasDevEnvParam = $PSBoundParameters.ContainsKey("DevEnv")
$HasFlutterSdkParam = $PSBoundParameters.ContainsKey("FlutterSdk")

$LocalConfig = Join-Path $PSScriptRoot "build_env.local.ps1"
if (Test-Path -LiteralPath $LocalConfig -PathType Leaf) {
  $LocalDevEnv = ""
  $LocalFlutterSdk = ""
  $LocalJdk = ""
  $LocalAndroidSdk = ""
  . $LocalConfig

  if (-not $HasDevEnvParam -and $LocalDevEnv) { $DevEnv = $LocalDevEnv }
  if (-not $HasFlutterSdkParam -and $LocalFlutterSdk) { $FlutterSdk = $LocalFlutterSdk }
  if ($LocalJdk) { $env:JAVA_HOME = $LocalJdk }
  if ($LocalAndroidSdk) {
    $env:ANDROID_HOME = $LocalAndroidSdk
    $env:ANDROID_SDK_ROOT = $LocalAndroidSdk
  }
}

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

if (-not $DevEnv) {
  $DevEnv = Resolve-FirstExistingDir @(
    (Join-Path $ProjectRoot "dev_env"),
    (Join-Path $ProjectRoot "..\dev_env")
  )
} elseif (Test-Path -LiteralPath $DevEnv -PathType Container) {
  $DevEnv = (Resolve-Path -LiteralPath $DevEnv).Path
}

$DevEnvFlutter = ""
if ($DevEnv) { $DevEnvFlutter = Join-Path $DevEnv "flutter" }

if (-not $FlutterSdk) {
  $FlutterSdk = Resolve-FlutterSdk @(
    $DevEnvFlutter,
    $env:FLUTTER_HOME
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

$Checks = @(
  [pscustomobject]@{ Name = "Project"; Path = $ProjectRoot; Required = "pubspec.yaml"; Ok = Test-Path -LiteralPath (Join-Path $ProjectRoot "pubspec.yaml") },
  [pscustomobject]@{ Name = "DevEnv"; Path = $DevEnv; Required = "jdk + android-sdk"; Ok = [bool]$DevEnv },
  [pscustomobject]@{ Name = "Flutter"; Path = $FlutterSdk; Required = "bin\flutter.bat"; Ok = $FlutterSdk -and (Test-Path -LiteralPath (Join-Path $FlutterSdk "bin\flutter.bat")) },
  [pscustomobject]@{ Name = "JDK"; Path = $Jdk; Required = "bin\java.exe"; Ok = $Jdk -and (Test-Path -LiteralPath (Join-Path $Jdk "bin\java.exe")) },
  [pscustomobject]@{ Name = "Android SDK"; Path = $AndroidSdk; Required = "platforms\android-35"; Ok = $AndroidSdk -and (Test-Path -LiteralPath (Join-Path $AndroidSdk "platforms\android-35\android.jar")) },
  [pscustomobject]@{ Name = "Android build-tools"; Path = $AndroidSdk; Required = "build-tools"; Ok = $AndroidSdk -and (Test-Path -LiteralPath (Join-Path $AndroidSdk "build-tools")) },
  [pscustomobject]@{ Name = "Android NDK"; Path = $AndroidSdk; Required = "ndk\27.0.12077973"; Ok = $AndroidSdk -and (Test-Path -LiteralPath (Join-Path $AndroidSdk "ndk\27.0.12077973")) }
)

$Checks | Format-Table Name, Ok, Required, Path -AutoSize

$failed = $Checks | Where-Object { -not $_.Ok }
if ($failed) {
  Write-Host ""
  Write-Error "Build environment is incomplete. See docs/portable build environment guide or BUILD_APK.md."
}

Write-Host ""
Write-Host "Build environment looks usable." -ForegroundColor Green

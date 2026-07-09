param(
  [string]$DevEnv = "",
  [string]$FlutterSdk = "",
  [switch]$SkipPubGet,
  [switch]$RunTests,
  [switch]$PrivateOwnerSync,
  [switch]$NoPrivateOwnerSync,
  [string[]]$ExtraFlutterArgs = @()
)

$ErrorActionPreference = "Stop"

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$HasDevEnvParam = $PSBoundParameters.ContainsKey("DevEnv")
$HasFlutterSdkParam = $PSBoundParameters.ContainsKey("FlutterSdk")
$DeepSellSyncToken = ""
$DeepSellSyncEmail = ""
$DeepSellSyncPassword = ""
$DeepSellFallbackBaseUrl = ""
$DefaultDeepSellFallbackVersionUrl = "https://42.193.131.66/api/version"
$DeepSellFallbackVersionUrl = $DefaultDeepSellFallbackVersionUrl
$ExpectedReleaseCertSha256 = "ada83336389b563a5d4260fe76c15f601a2766187aec78c74b1242b382beadac"
$ReleaseKeystore = ""
$ReleaseKeyAlias = "boss"
$ReleaseStorePassword = ""
$ReleaseKeyPassword = ""

$LocalConfig = Join-Path $PSScriptRoot "build_env.local.ps1"
if (Test-Path -LiteralPath $LocalConfig -PathType Leaf) {
  $LocalDevEnv = ""
  $LocalFlutterSdk = ""
  $LocalJdk = ""
  $LocalAndroidSdk = ""
  $LocalReleaseKeystore = ""
  $LocalReleaseKeyAlias = ""
  $LocalReleaseStorePassword = ""
  $LocalReleaseKeyPassword = ""
  $DeepSellSyncToken = ""
  $DeepSellSyncEmail = ""
  $DeepSellSyncPassword = ""
  $DeepSellFallbackBaseUrl = ""
  $DeepSellFallbackVersionUrl = $DefaultDeepSellFallbackVersionUrl
  . $LocalConfig

  if (-not $HasDevEnvParam -and $LocalDevEnv) { $DevEnv = $LocalDevEnv }
  if (-not $HasFlutterSdkParam -and $LocalFlutterSdk) { $FlutterSdk = $LocalFlutterSdk }
  if ($LocalJdk) { $env:JAVA_HOME = $LocalJdk }
  if ($LocalAndroidSdk) {
    $env:ANDROID_HOME = $LocalAndroidSdk
    $env:ANDROID_SDK_ROOT = $LocalAndroidSdk
  }
  if ($LocalReleaseKeystore) { $ReleaseKeystore = $LocalReleaseKeystore }
  if ($LocalReleaseKeyAlias) { $ReleaseKeyAlias = $LocalReleaseKeyAlias }
  if ($LocalReleaseStorePassword) { $ReleaseStorePassword = $LocalReleaseStorePassword }
  if ($LocalReleaseKeyPassword) { $ReleaseKeyPassword = $LocalReleaseKeyPassword }
}

function Add-DartDefine {
  param(
    [System.Collections.Generic.List[string]]$ArgList,
    [string]$Name,
    [string]$Value
  )
  if ($Value) {
    $ArgList.Add("--dart-define=$Name=$Value")
  }
}

function Resolve-PubspecVersion {
  param([string]$ProjectRoot)
  $pubspec = Join-Path $ProjectRoot "pubspec.yaml"
  $line = Get-Content -LiteralPath $pubspec -Encoding UTF8 |
    Where-Object { $_ -match "^\s*version:\s*(.+?)\s*$" } |
    Select-Object -First 1
  if (-not $line) { return @{ Version = ""; Build = "" } }
  $raw = ($line -replace "^\s*version:\s*", "").Trim()
  $parts = $raw.Split("+", 2)
  $build = ""
  if ($parts.Length -gt 1) { $build = $parts[1] }
  return @{
    Version = $parts[0]
    Build = $build
  }
}

function First-NonEmpty {
  param([string]$Primary, [string]$Fallback)
  if ($Primary) { return $Primary }
  return $Fallback
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

function To-PropertiesPath {
  param([string]$Path)
  return $Path.Replace("\", "/")
}

function Get-KeystoreCertSha256 {
  param(
    [string]$Keystore,
    [string]$Alias,
    [string]$StorePass
  )

  $keytool = Join-Path $env:JAVA_HOME "bin\keytool.exe"
  if (-not (Test-Path -LiteralPath $keytool -PathType Leaf)) {
    throw "keytool not found under JAVA_HOME."
  }

  $pem = & $keytool -exportcert -rfc -keystore $Keystore -alias $Alias -storepass $StorePass 2>$null
  if ($LASTEXITCODE -ne 0 -or -not $pem) {
    throw "Unable to read release signing certificate from $Keystore."
  }

  $base64 = ($pem | Where-Object { $_ -notmatch "^-+.*-+$" }) -join ""
  $bytes = [Convert]::FromBase64String($base64)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-", "").ToLowerInvariant()
  } finally {
    $sha.Dispose()
  }
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

$DefaultReleaseKeystore = ""
if ($DevEnv) {
  $DefaultReleaseKeystore = Join-Path $DevEnv "keys\ipad_boss_release.jks"
}
if (-not $ReleaseKeystore -and $DefaultReleaseKeystore -and (Test-Path -LiteralPath $DefaultReleaseKeystore -PathType Leaf)) {
  $ReleaseKeystore = $DefaultReleaseKeystore
}
if (-not $ReleaseKeyPassword -and $ReleaseStorePassword) {
  $ReleaseKeyPassword = $ReleaseStorePassword
}
if ($ReleaseKeystore -and (Test-Path -LiteralPath $ReleaseKeystore -PathType Leaf)) {
  $ReleaseKeystore = (Resolve-Path -LiteralPath $ReleaseKeystore).Path
}

$missingSigningConfig = @()
if (-not $ReleaseKeystore) { $missingSigningConfig += "`$LocalReleaseKeystore" }
if (-not $ReleaseKeyAlias) { $missingSigningConfig += "`$LocalReleaseKeyAlias" }
if (-not $ReleaseStorePassword) { $missingSigningConfig += "`$LocalReleaseStorePassword" }
if (-not $ReleaseKeyPassword) { $missingSigningConfig += "`$LocalReleaseKeyPassword" }
if ($missingSigningConfig.Count -gt 0) {
  throw "Release signing is incomplete. Configure $($missingSigningConfig -join ', ') in tools\build_env.local.ps1. See docs\apk-signing.md."
}
if (-not (Test-Path -LiteralPath $ReleaseKeystore -PathType Leaf)) {
  throw "Release keystore not found: $ReleaseKeystore. See docs\apk-signing.md."
}

$ReleaseCertSha256 = Get-KeystoreCertSha256 $ReleaseKeystore $ReleaseKeyAlias $ReleaseStorePassword
if ($ReleaseCertSha256 -ne $ExpectedReleaseCertSha256) {
  throw "Release keystore SHA256 mismatch. Expected $ExpectedReleaseCertSha256 but found $ReleaseCertSha256. Use the shared release keystore documented in docs\apk-signing.md."
}

$localProperties = @(
  "sdk.dir=$(To-PropertiesPath $AndroidSdk)",
  "flutter.sdk=$(To-PropertiesPath $FlutterSdk)",
  "flutter.buildMode=release",
  "release.storeFile=$(To-PropertiesPath $ReleaseKeystore)",
  "release.keyAlias=$ReleaseKeyAlias",
  "release.storePassword=$ReleaseStorePassword",
  "release.keyPassword=$ReleaseKeyPassword"
)
Set-Content -LiteralPath (Join-Path $ProjectRoot "android\local.properties") -Value $localProperties -Encoding ASCII

$Flutter = Join-Path $FlutterSdk "bin\flutter.bat"
Write-Host "Project:     $ProjectRoot"
Write-Host "Flutter SDK: $FlutterSdk"
Write-Host "JDK:         $Jdk"
Write-Host "Android SDK: $AndroidSdk"
Write-Host "Keystore:    $ReleaseKeystore"
Write-Host "Release cert SHA256: $ReleaseCertSha256"
Write-Host ""

Push-Location $ProjectRoot
try {
  & $Flutter --version

  $PackageConfig = Join-Path $ProjectRoot ".dart_tool\package_config.json"
  $ShouldPubGet = -not $SkipPubGet
  if ($SkipPubGet) {
    if (-not (Test-Path -LiteralPath $PackageConfig -PathType Leaf)) {
      $ShouldPubGet = $true
      Write-Host "Dependencies are not initialized yet; running flutter pub get once."
    } else {
      $packageConfigTime = (Get-Item -LiteralPath $PackageConfig).LastWriteTimeUtc
      $dependencyFiles = @(
        (Join-Path $ProjectRoot "pubspec.yaml"),
        (Join-Path $ProjectRoot "pubspec.lock")
      ) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }

      foreach ($file in $dependencyFiles) {
        if ((Get-Item -LiteralPath $file).LastWriteTimeUtc -gt $packageConfigTime) {
          $ShouldPubGet = $true
          Write-Host "Dependency files changed; running flutter pub get."
          break
        }
      }
    }
  }

  if ($ShouldPubGet) {
    & $Flutter pub get
  } else {
    Write-Host "Skipping flutter pub get."
  }

  if ($RunTests) {
    & $Flutter test
  }

  $BuildArgs = [System.Collections.Generic.List[string]]::new()
  $BuildArgs.Add("build")
  $BuildArgs.Add("apk")
  $BuildArgs.Add("--release")
  $AppVersion = Resolve-PubspecVersion $ProjectRoot
  Add-DartDefine $BuildArgs "DEEPSELL_APP_VERSION" $AppVersion.Version
  Add-DartDefine $BuildArgs "DEEPSELL_APP_BUILD" $AppVersion.Build
  foreach ($arg in $ExtraFlutterArgs) { $BuildArgs.Add($arg) }
  $OwnerSyncToken = First-NonEmpty $env:DEEPSELL_SYNC_TOKEN $DeepSellSyncToken
  $OwnerSyncEmail = First-NonEmpty $env:DEEPSELL_SYNC_EMAIL $DeepSellSyncEmail
  $OwnerSyncPassword = First-NonEmpty $env:DEEPSELL_SYNC_PASSWORD $DeepSellSyncPassword
  $FallbackBaseUrl = First-NonEmpty $env:DEEPSELL_FALLBACK_BASE_URL $DeepSellFallbackBaseUrl
  $FallbackVersionUrl = First-NonEmpty $env:DEEPSELL_FALLBACK_VERSION_URL $DeepSellFallbackVersionUrl
  if ($FallbackBaseUrl -or $FallbackVersionUrl) {
    Add-DartDefine $BuildArgs "DEEPSELL_ALLOW_INSECURE_IP_FALLBACK" "true"
    Add-DartDefine $BuildArgs "DEEPSELL_FALLBACK_BASE_URL" $FallbackBaseUrl
    Add-DartDefine $BuildArgs "DEEPSELL_FALLBACK_VERSION_URL" $FallbackVersionUrl
    Write-Host "Fallback update endpoint: included."
  }
  $HasOwnerCredential = $OwnerSyncToken -or ($OwnerSyncEmail -and $OwnerSyncPassword)
  $IncludePrivateOwnerSync = (-not $NoPrivateOwnerSync) -and ($PrivateOwnerSync -or $HasOwnerCredential)
  if ($IncludePrivateOwnerSync) {
    if (-not $HasOwnerCredential) {
      throw "Private owner sync was requested, but no token or email/password credential is configured."
    }
    Add-DartDefine $BuildArgs "DEEPSELL_PRIVATE_OWNER_SYNC" "true"
    Add-DartDefine $BuildArgs "DEEPSELL_SYNC_TOKEN" $OwnerSyncToken
    Add-DartDefine $BuildArgs "DEEPSELL_SYNC_EMAIL" $OwnerSyncEmail
    Add-DartDefine $BuildArgs "DEEPSELL_SYNC_PASSWORD" $OwnerSyncPassword
    Write-Host "Private owner background sync: included."
  } elseif ($NoPrivateOwnerSync) {
    Write-Host "Private owner background sync: disabled by -NoPrivateOwnerSync."
  } else {
    Write-Host "Private owner background sync: no local credential configured."
  }

  & $Flutter @BuildArgs

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

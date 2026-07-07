# APK 构建指南

本文档是项目构建 APK 的主入口。目标是：仓库保持轻量；新电脑按这里下载 SDK 到相对目录后，可以直接复用同一条构建命令。

## 推荐目录结构

把 `dev_env` 放在项目同级：

```text
workspace/
  dev_env/
    android-sdk/
    flutter/
    jdk-17.0.13+11/
  ipad_boss_app/
    android/
    lib/
    tools/
```

进入 `ipad_boss_app` 后，日常构建命令固定为：

```powershell
powershell -ExecutionPolicy Bypass -File tools\build_apk.ps1 -SkipPubGet
```

第一次运行时，如果依赖还没初始化，脚本会自动补一次依赖拉取；之后会按 `-SkipPubGet` 正常跳过。

## 当前验证过的版本

| 项目 | 版本 / 要求 |
|---|---|
| Flutter | 3.29.0 |
| Dart | 3.7.0 |
| JDK | 17 |
| Android SDK Platform | android-36 |
| Android Build Tools | 36.0.0 |
| Android NDK | 27.0.12077973 |
| Android Gradle Plugin | 8.13.2 |
| Gradle Wrapper | 8.13 |
| Kotlin | 2.2.0 |
| Android SDK 版本 | minSdk 24 / targetSdk 36 / compileSdk 36 |

## 新电脑下载环境

这些 SDK 不提交到 Git，也不建议作为 8GB 压缩包上传。新电脑按下面步骤下载到 `..\dev_env` 即可。

### 1. 创建目录

在项目根目录执行：

```powershell
New-Item -ItemType Directory -Force ..\dev_env, ..\dev_env\android-sdk | Out-Null
```

### 2. 下载 Flutter SDK

下载 Flutter 3.29.0 Windows SDK：

```text
https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.29.0-stable.zip
```

解压后保证这个文件存在：

```text
..\dev_env\flutter\bin\flutter.bat
```

官方版本归档页：

```text
https://docs.flutter.dev/install/archive
```

### 3. 下载 JDK 17

下载 Temurin JDK 17 Windows x64 zip，解压到 `..\dev_env` 下，目录名以 `jdk` 开头即可，例如：

```text
..\dev_env\jdk-17.0.13+11\bin\java.exe
```

官方下载页：

```text
https://adoptium.net/temurin/releases/?version=17&os=windows&arch=x64&package=jdk
```

### 4. 下载 Android Command-line Tools

从 Android 官方页面下载 Windows 版 Command-line tools：

```text
https://developer.android.com/studio
```

解压时注意目录层级，最终需要是：

```text
..\dev_env\android-sdk\cmdline-tools\latest\bin\sdkmanager.bat
```

如果解压后出现 `cmdline-tools\bin`，需要把里面的 `bin`、`lib` 等内容移动到 `cmdline-tools\latest` 下。

### 5. 安装 Android SDK 组件

在项目根目录执行：

```powershell
$Jdk = Get-ChildItem ..\dev_env -Directory -Filter "jdk*" | Select-Object -First 1
$env:JAVA_HOME = $Jdk.FullName
$env:ANDROID_HOME = (Resolve-Path ..\dev_env\android-sdk).Path
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:Path = "$env:JAVA_HOME\bin;$env:ANDROID_HOME\cmdline-tools\latest\bin;$env:ANDROID_HOME\platform-tools;$env:Path"

sdkmanager.bat --licenses
sdkmanager.bat "platform-tools" "platforms;android-36" "build-tools;36.0.0" "ndk;27.0.12077973"
```

`sdkmanager` 官方说明：

```text
https://developer.android.com/tools/sdkmanager
```

## 检查环境

```powershell
powershell -ExecutionPolicy Bypass -File tools\check_build_env.ps1
```

看到 `Build environment looks usable.` 后即可构建。

## 构建 Release APK

```powershell
powershell -ExecutionPolicy Bypass -File tools\build_apk.ps1 -SkipPubGet
```

构建成功后输出：

```text
build\app\outputs\flutter-apk\app-release.apk
```

脚本会打印 APK 的 SHA256，方便确认文件没有拿错。

Release 构建使用 `flutter analyze` 和测试作为质量门槛。Windows 上 Android lint 的 release cache 偶发文件锁占用，因此 release 构建关闭 `checkReleaseBuilds`，避免误判失败。

## 本地路径配置

脚本会自动查找：

1. `tools\build_env.local.ps1` 中的本机路径配置
2. `项目根目录\dev_env`
3. `项目根目录\..\dev_env`
4. 环境变量 `FLUTTER_HOME` / `JAVA_HOME` / `ANDROID_HOME`
5. 系统 `PATH` 里的 Flutter 命令

如果某台机器路径特殊，可以复制模板：

```powershell
Copy-Item tools\build_env.local.ps1.example tools\build_env.local.ps1
```

然后把里面的路径改成自己的。`tools\build_env.local.ps1` 不会提交到 Git。

## local.properties

`android/local.properties` 是本机路径文件，不提交。脚本会自动生成它。

如果要手动写，可参考：

```text
sdk.dir=../../dev_env/android-sdk
flutter.sdk=../../dev_env/flutter
flutter.buildMode=release
```

这里的相对路径从 `android/` 目录开始计算；日常更推荐让构建脚本自动生成。

## 不推荐上传完整 SDK 包

`tools\package_portable_env.ps1` 可以复制完整 Flutter / Android SDK / JDK，但实测体积约 8GB，压缩也很慢。除非内网离线分发，否则不推荐使用。

如果确实要打完整离线包，需要显式确认：

```powershell
powershell -ExecutionPolicy Bypass -File tools\package_portable_env.ps1 -AllowLargePackage -Zip
```

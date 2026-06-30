# 机掌柜 Flutter 项目：Windows 环境搭建与 APK 构建指南

> 本文档是 Linux 版《构建与上传全流程指南》的 Windows 补充，记录在 **Windows 10/11** 环境下从零搭建 Flutter Android 构建环境、打包 release APK 的完整过程。涵盖安装、踩坑、环境变量配置、一键构建脚本等。

---

## 目录

1. [版本选型总览](#1-版本选型总览)
2. [安装目录约定](#2-安装目录约定)
3. [第一步：安装 JDK 17](#3-第一步安装-jdk-17)
4. [第二步：安装 Flutter SDK](#4-第二步安装-flutter-sdk)
5. [第三步：安装 Android SDK](#5-第三步安装-android-sdk)
6. [第四步：配置环境变量](#6-第四步配置环境变量)
7. [第五步：配置 local.properties](#7-第五步配置-localproperties)
8. [第六步：构建 release APK](#8-第六步构建-release-apk)
9. [第七步：验证 APK](#9-第七步验证-apk)
10. [一键构建脚本 build.bat](#10-一键构建脚本-buildbat)
11. [常见报错与解决方案](#11-常见报错与解决方案)
12. [附录：关键文件清单](#12-附录关键文件清单)

---

## 1. 版本选型总览

本项目 `pubspec.yaml` 约束 `sdk: ">=2.17.0 <3.0.0"`，对应 **Flutter 3.0.0**。各组件版本必须互相兼容，**不要随意升级**。

| 组件 | 实际使用版本 | 说明 |
|---|---|---|
| **Flutter SDK** | 3.0.0 (stable, Dart 2.17.0) | 匹配 `pubspec.yaml` SDK 约束 |
| **JDK** | Temurin 17.0.13 | AGP 7.1.2 要求 JDK 11+ |
| **AGP** | 7.1.2 | 项目已有配置，不动 |
| **Gradle** | 7.4 (wrapper) | AGP 7.1.2 兼容，由 wrapper 自动下载 |
| **Kotlin** | 1.7.10 | 项目已有配置，不动 |
| **compileSdk** | 33 | 项目已有配置 |
| **build-tools** | 33.0.0 | 匹配 compileSdk 33 |
| **platform-tools** | 最新 | 含 adb |
| **platforms** | android-33 | 匹配 compileSdk 33 |

> **兼容性矩阵**：`JDK17 + AGP7.1.2 + Gradle7.4 + Kotlin1.7.10 + compileSdk33`，已实测通过。

---

## 2. 安装目录约定

Windows 下建议将所有工具放在**项目内的一个统一目录**中，方便管理和迁移。本文假设：

```
D:\V881\padtest\               ← 项目根目录（你的实际路径可能不同）
├── ipad_boss_app\              ← Flutter 项目代码
│   ├── docs\                   ← 本文档所在位置
│   └── ...
└── dev_env\                    ← 开发环境工具集中目录
    ├── jdk-17.0.13+11\         ← JDK 17
    ├── flutter\                ← Flutter SDK
    └── android-sdk\            ← Android SDK
```

> 你也可以将工具安装在其他位置（如 `D:\dev_env\`），本文后续所有路径都基于此结构，请按实际路径调整。

---

## 3. 第一步：安装 JDK 17

### 3.1 下载

从 Adoptium 官网下载 Windows x64 压缩包（zip 版无需安装，解压即用）：

- **下载地址**：https://adoptium.net/temurin/releases/?version=17
- **选择**：Windows → x64 → JDK → 17.0.13 → `.zip` 包
- **直接链接**：`https://api.adoptium.net/v3/binary/version/jdk-17.0.13%2B11/windows/x64/jdk/hotspot/normal/eclipse?project=jdk`

### 3.2 安装（解压）

将下载的 zip 解压到 `dev_env\` 目录下：

```bash
# 假设在项目根目录 D:\V881\padtest\
mkdir dev_env
unzip -q jdk-17.0.13+11.zip -d dev_env\
```

解压后目录结构应为：`dev_env\jdk-17.0.13+11\bin\java.exe`

### 3.3 验证

```bash
dev_env\jdk-17.0.13+11\bin\java -version
# 期望输出：openjdk version "17.0.13" 2024-10-15
```

---

## 4. 第二步：安装 Flutter SDK

### 4.1 下载

获取 Flutter 3.0.0 Windows 稳定版：

```bash
# 方法一：直接下载 zip
curl -sL -o flutter.zip "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.0.0-stable.zip"

# 方法二：如果已装其他版本 Flutter，切到 3.0.0
cd /path/to/flutter
git checkout 3.0.0
```

### 4.2 安装（解压）

```bash
unzip -q flutter.zip -d dev_env\
# 解压后得到 dev_env\flutter\
```

### 4.3 验证

```bash
dev_env\flutter\bin\flutter --version
# 期望输出：Flutter 3.0.0 • channel stable • Dart version 2.17.0
```

> 首次运行 `flutter --version` 会自动解压 Dart SDK 并初始化。如遇到网络问题，确保你的环境可以访问 `storage.googleapis.com`。

---

## 5. 第三步：安装 Android SDK

Windows 下需通过 **commandline-tools**（即 `sdkmanager.bat`）来安装 SDK 组件。

### 5.1 下载并解压 cmdline-tools

```bash
curl -sL -o cmdline-tools.zip "https://dl.google.com/android/repository/commandlinetools-win-9477386_latest.zip"
mkdir -p dev_env\android-sdk\cmdline-tools
unzip -q cmdline-tools.zip -d dev_env\android-sdk\cmdline-tools\
# ⚠️ 必须重命名为 latest
move dev_env\android-sdk\cmdline-tools\cmdline-tools dev_env\android-sdk\cmdline-tools\latest
```

关键点：最终路径必须是 `dev_env\android-sdk\cmdline-tools\latest\bin\sdkmanager.bat`，否则会报找不到根目录。

### 5.2 安装 SDK 组件

**注意**：在 Windows 上直接 `echo y | sdkmanager.bat` 不管用（bat 文件管道 stdin 有 Bug），需要用 **PowerShell** 配合输入文件来绕过。

方法一（推荐）—— 使用 PowerShell：

```powershell
# 在 PowerShell 中执行
$env:JAVA_HOME = "D:\V881\padtest\dev_env\jdk-17.0.13+11"
$env:ANDROID_SDK_ROOT = "D:\V881\padtest\dev_env\android-sdk"
$env:ANDROID_HOME = "D:\V881\padtest\dev_env\android-sdk"
$env:Path = "$env:JAVA_HOME\bin;$env:ANDROID_SDK_ROOT\cmdline-tools\latest\bin;$env:Path"

# 安装（PowerShell 管道可以正确传递 stdin）
& "D:\V881\padtest\dev_env\android-sdk\cmdline-tools\latest\bin\sdkmanager.bat" --sdk_root=$env:ANDROID_SDK_ROOT "platform-tools" "platforms;android-33" "build-tools;33.0.0"
```

方法二 —— 使用 `yes.txt` 输入文件：

```bash
# 在 Git Bash / CMD 中
echo yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy > yes.txt
cmd /c "sdkmanager.bat --sdk_root=ANDROID_SDK_ROOT --licenses < yes.txt"
cmd /c "sdkmanager.bat --sdk_root=ANDROID_SDK_ROOT platform-tools platforms;android-33 build-tools;33.0.0 < yes.txt"
```

验证安装结果：

```bash
dev_env\android-sdk\build-tools\33.0.0\aapt.exe version
dev_env\android-sdk\platform-tools\adb.exe --version
dir dev_env\android-sdk\platforms\android-33\android.jar
```

### 5.3 把 SDK 路径告诉 Flutter

```bash
dev_env\flutter\bin\flutter config --android-sdk D:\V881\padtest\dev_env\android-sdk
dev_env\flutter\bin\flutter doctor
# 期望：[✓] Android toolchain（Android SDK version 33.0.0）
```

---

## 6. 第四步：配置环境变量

每次构建前需要设置以下环境变量。推荐写成一个 **构建脚本**（见第 10 节），也可以设置到系统环境变量中持久化。

### 6.1 临时设置（每次开新终端执行）

```bash
# Git Bash 风格
export JAVA_HOME="/d/V881/padtest/dev_env/jdk-17.0.13+11"
export ANDROID_HOME="/d/V881/padtest/dev_env/android-sdk"
export ANDROID_SDK_ROOT="/d/V881/padtest/dev_env/android-sdk"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:/d/V881/padtest/dev_env/flutter/bin:$PATH"
```

```powershell
# PowerShell 风格
$env:JAVA_HOME = "D:\V881\padtest\dev_env\jdk-17.0.13+11"
$env:ANDROID_HOME = "D:\V881\padtest\dev_env\android-sdk"
$env:ANDROID_SDK_ROOT = "D:\V881\padtest\dev_env\android-sdk"
$env:Path = "$env:JAVA_HOME\bin;$env:ANDROID_HOME\platform-tools;$env:ANDROID_HOME\cmdline-tools\latest\bin;D:\V881\padtest\dev_env\flutter\bin;$env:Path"
```

### 6.2 持久化设置（系统环境变量）

1. 右键「此电脑」→「属性」→「高级系统设置」→「环境变量」
2. 新建系统变量：
   - `JAVA_HOME` = `D:\V881\padtest\dev_env\jdk-17.0.13+11`
   - `ANDROID_HOME` = `D:\V881\padtest\dev_env\android-sdk`
   - `ANDROID_SDK_ROOT` = `D:\V881\padtest\dev_env\android-sdk`
3. 编辑 `Path` 变量，添加：
   - `%JAVA_HOME%\bin`
   - `%ANDROID_HOME%\platform-tools`
   - `%ANDROID_HOME%\cmdline-tools\latest\bin`
   - `D:\V881\padtest\dev_env\flutter\bin`

> ⚠️ **JDK 17 的 JAVA_HOME 必须用 Windows 路径格式**（`D:\` 前缀），不能使用 Git Bash 风格的 `/d/` 前缀，否则 Gradle 会报 `JAVA_HOME is set to an invalid directory`。

---

## 7. 第五步：配置 local.properties

`android/local.properties` 是 Flutter 构建的关键文件，告诉 Gradle Android SDK 和 Flutter SDK 在哪。

```properties
sdk.dir=D\:\\V881\\padtest\\dev_env\\android-sdk
flutter.sdk=D\:\\V881\\padtest\\dev_env\\flutter
flutter.buildMode=release
flutter.versionName=1.6.0
flutter.versionCode=6
```

> 注意：路径中的 `\` 要转义为 `\\`，或者用 `/` 代替。上面的例子中 `D\:\\V881` 中的反斜杠在 properties 文件中需写为 `D:\\V881`。

也可以直接用 Git Bash 创建：

```bash
cat > android/local.properties << 'EOF'
sdk.dir=D\:\\V881\\padtest\\dev_env\\android-sdk
flutter.sdk=D\:\\V881\\padtest\\dev_env\\flutter
flutter.buildMode=release
flutter.versionName=1.6.0
flutter.versionCode=6
EOF
```

---

## 8. 第六步：构建 release APK

确保 `android/app/build.gradle` 中的 `compileSdkVersion` 与你安装的 platform 版本一致（都是 33）。项目中已配置好 release 签名（`release-keystore.jks`，alias=boss，密码=123456）。

### 8.1 拉依赖

```bash
cd D:\V881\padtest\ipad_boss_app
dev_env\flutter\bin\flutter pub get
```

### 8.2 构建 APK

```bash
# 设置环境变量（如果没持久化）
export JAVA_HOME="/d/V881/padtest/dev_env/jdk-17.0.13+11"
export ANDROID_HOME="/d/V881/padtest/dev_env/android-sdk"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:/d/V881/padtest/dev_env/flutter/bin:$PATH"

# 构建
flutter build apk --release
```

构建成功后输出：

```
✓  Built build\app\outputs\flutter-apk\app-release.apk (19.9MB).
```

APK 文件位置：`build\app\outputs\flutter-apk\app-release.apk`

---

## 9. 第七步：验证 APK

验证 APK 的包名、版本和权限：

```bash
# 使用 aapt 查看 APK 信息
dev_env\android-sdk\build-tools\33.0.0\aapt.exe dump badging build\app\outputs\flutter-apk\app-release.apk | findstr "package: application-label: uses-permission:"
```

期望输出包含：
- `package: name='com.ipadboss.ipad_boss_app'`
- `uses-permission: name='android.permission.INTERNET'`
- `application-label:'机掌柜'`

---

## 10. 一键构建脚本 build.bat

将以下内容保存为 `build.bat` 放在项目根目录，下次双击即可构建：

```batch
@echo off
chcp 65001 >nul
setlocal

REM ===== 项目路径（按实际修改） =====
set PROJECT_DIR=D:\V881\padtest\ipad_boss_app
set DEV_ENV_DIR=D:\V881\padtest\dev_env

REM ===== 环境变量 =====
set JAVA_HOME=%DEV_ENV_DIR%\jdk-17.0.13+11
set ANDROID_HOME=%DEV_ENV_DIR%\android-sdk
set ANDROID_SDK_ROOT=%DEV_ENV_DIR%\android-sdk
set PATH=%JAVA_HOME%\bin;%ANDROID_HOME%\platform-tools;%ANDROID_HOME%\cmdline-tools\latest\bin;%DEV_ENV_DIR%\flutter\bin;%PATH%

echo ===== 1. 拉取依赖 =====
cd /d "%PROJECT_DIR%"
call flutter pub get
if %ERRORLEVEL% neq 0 (
    echo [ERROR] flutter pub get 失败
    pause
    exit /b 1
)

echo ===== 2. 构建 Release APK =====
call flutter build apk --release
if %ERRORLEVEL% neq 0 (
    echo [ERROR] flutter build 失败
    pause
    exit /b 1
)

echo ===== 构建完成 =====
echo APK: %PROJECT_DIR%\build\app\outputs\flutter-apk\app-release.apk
pause
```

> 也可以在 PowerShell 中运行：`.\build.bat`。如需上传到 gofile，参考 Linux 版的 curl 命令部分，替换文件路径即可。

### 一键构建脚本 PowerShell 版

```powershell
# build.ps1
$ErrorActionPreference = "Stop"
$ProjectDir = "D:\V881\padtest\ipad_boss_app"
$DevEnv = "D:\V881\padtest\dev_env"

$env:JAVA_HOME = "$DevEnv\jdk-17.0.13+11"
$env:ANDROID_HOME = "$DevEnv\android-sdk"
$env:ANDROID_SDK_ROOT = "$DevEnv\android-sdk"
$env:Path = "$env:JAVA_HOME\bin;$env:ANDROID_HOME\platform-tools;$env:ANDROID_HOME\cmdline-tools\latest\bin;$DevEnv\flutter\bin;$env:Path"

Set-Location $ProjectDir
Write-Output "=== flutter pub get ==="
flutter pub get
Write-Output "=== flutter build apk --release ==="
flutter build apk --release
Write-Output "=== 完成 ==="
Write-Output "APK: $ProjectDir\build\app\outputs\flutter-apk\app-release.apk"
```

使用方式：右键 → 使用 PowerShell 运行，或 `powershell -ExecutionPolicy Bypass -File build.ps1`

---

## 11. 常见报错与解决方案

### ❌ 报错 1：`JAVA_HOME is set to an invalid directory`

```
ERROR: JAVA_HOME is set to an invalid directory: /d/V881/padtest/dev_env/jdk-17.0.13+11
```

**根因**：`JAVA_HOME` 使用了 Git Bash 风格的路径（`/d/` 前缀），但 Gradle（Java 进程）需要 Windows 原生路径。

**解决**：将 `JAVA_HOME` 设置为 Windows 路径格式：

```bash
# ❌ 错误（Git Bash 风格）
export JAVA_HOME="/d/V881/padtest/dev_env/jdk-17.0.13+11"

# ✅ 正确（Windows 风格）
export JAVA_HOME="D:\\V881\\padtest\\dev_env\\jdk-17.0.13+11"

# 或者在同一个终端里先 export JAVA_HOME 再调用 flutter
```

> 注意：`PATH` 变量中的程序路径可以用 Git Bash 风格（`/d/`），但 `JAVA_HOME` **必须**用 Windows 风格，因为它是直接给 Java 进程读取的。

### ❌ 报错 2：license 无法接受（`echo y | sdkmanager.bat` 无效）

**根因**：Windows 上 `.bat` 文件的 stdin 管道存在已知限制，`echo y | sdkmanager.bat` 不会生效。

**解决**：使用 PowerShell 执行，PowerShell 的管道能正确处理：

```powershell
$env:JAVA_HOME = "D:\path\to\jdk"
$env:ANDROID_SDK_ROOT = "D:\path\to\android-sdk"
$env:Path = "$env:JAVA_HOME\bin;$env:ANDROID_SDK_ROOT\cmdline-tools\latest\bin;$env:Path"
# PowerShell 管道可以正确传递输入
"y" * 50 | & "D:\path\to\android-sdk\cmdline-tools\latest\bin\sdkmanager.bat" --sdk_root=$env:ANDROID_SDK_ROOT "platform-tools"
```

### ❌ 报错 3：Kotlin 元数据版本不匹配

```
Module was compiled with an incompatible version of Kotlin. The binary version of its metadata is 1.7.1, expected version is 1.5.1.
```

**根因**：某些依赖库使用了更新的 Kotlin 版本编译。

**解决**：这些是 **warning 级别**的提示，**不会阻止构建成功**。只要最终 APK 生成即可忽略。如果你想要消除这些 warning，可以升级 `android/build.gradle` 中的 Kotlin 版本，但同时需要同步升级 AGP，改动较大，**不建议**。

### ❌ 报错 4：`Android SDK file not found: platforms\android-33\android.jar`

**根因**：Flutter 配置的 Android SDK 路径不对，或者 platform 没有完整安装（只创建了空目录）。

**解决**：
```bash
# 用 sdkmanager 重新安装 platform
sdkmanager.bat --sdk_root=D:\path\to\android-sdk "platforms;android-33"
# 然后确认 android.jar 存在
dir D:\path\to\android-sdk\platforms\android-33\android.jar
```

### ❌ 报错 5：`Could not find or load main class org.gradle.wrapper.GradleWrapperMain`

**根因**：`gradle-wrapper.jar` 缺失或损坏。

**解决**：从其他 Flutter 项目复制，或重新 `flutter create` 生成模板：
```bash
flutter create --platforms=android --project-name ipad_boss_app temp_project
cp temp_project/android/gradle/wrapper/gradle-wrapper.jar android/gradle/wrapper/
```

> 当前项目已有完整的 android 目录结构，通常不会遇到此问题。

### ❌ 报错 6：`Failed host lookup: 'api.deepseek.com'`

**根因**：release 版 `AndroidManifest.xml` 缺少 `INTERNET` 权限。

**解决**：确保 `android/app/src/main/AndroidManifest.xml` 中包含：
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
```

### ❌ 报错 7：`unable to find valid certification path to requested target`

**根因**：Gradle 下载依赖时遇到 SSL 证书问题（常见于公司内网或沙箱环境）。

**解决**：配置 Gradle 使用腾讯镜像或阿里云镜像，在 `android/build.gradle` 中修改 repositories：

```gradle
repositories {
    maven { url 'https://mirrors.tencent.com/nexus/repository/maven-public/' }
    mavenCentral()
    google()
}
```

---

## 12. 附录：关键文件清单

```
D:\V881\padtest\
├── dev_env\                               ← 开发环境工具目录
│   ├── jdk-17.0.13+11\                    ← JDK 17
│   │   └── bin\java.exe
│   ├── flutter\                           ← Flutter SDK 3.0.0
│   │   └── bin\flutter.exe
│   └── android-sdk\                       ← Android SDK
│       ├── cmdline-tools\latest\bin\      ← sdkmanager.bat
│       ├── platform-tools\                ← adb.exe
│       ├── platforms\android-33\          ← android.jar
│       └── build-tools\33.0.0\            ← aapt, apksigner
│
├── ipad_boss_app\                         ← Flutter 项目
│   ├── android\
│   │   ├── local.properties               ← SDK 路径配置
│   │   ├── build.gradle                   ← AGP 7.1.2 + Kotlin 1.7.10
│   │   ├── gradle\wrapper\                ← Gradle 7.4 wrapper
│   │   └── app\
│   │       ├── build.gradle               ← 编译配置 + 签名
│   │       ├── release-keystore.jks       ← 签名密钥
│   │       └── src\main\AndroidManifest.xml ← INTERNET 权限
│   ├── build\app\outputs\flutter-apk\     ← 构建产物
│   │   └── app-release.apk
│   └── docs\
│       ├── 构建与上传全流程指南.md         ← Linux 版
│       └── Windows环境搭建与构建指南.md    ← 本文档
└── build.bat                              ← 一键构建脚本（可选）
```

---

## 版本对照表

| 项目 | 值 |
|---|---|
| Flutter | 3.0.0 |
| Dart | 2.17.0 |
| JDK | 17.0.13 (Temurin) |
| AGP | 7.1.2 |
| Gradle | 7.4 |
| Kotlin | 1.7.10 |
| compileSdk | 33 |
| build-tools | 33.0.0 |
| platforms | android-33 |
| ANDROID_SDK_ROOT | `D:\V881\padtest\dev_env\android-sdk` |
| JAVA_HOME | `D:\V881\padtest\dev_env\jdk-17.0.13+11` |

> ⚠️ **Windows 下 JAVA_HOME 必须使用 `D:\` 格式的绝对路径**，不要用 `/d/` 的 Git Bash 风格。这是 Windows 上构建最容易踩的坑。

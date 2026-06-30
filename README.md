# 机掌柜

二手 iPad 门店经营工具，用于扫码收货、库存管理、定价、售出、利润统计、AI 经营分析和数据备份。

## 快速开始

先按 [BUILD_APK.md](BUILD_APK.md) 下载 Flutter / Android SDK / JDK，让 `dev_env` 和项目目录同级：

```text
workspace/
  dev_env/
  ipad_boss_app/
```

然后在项目根目录执行：

```powershell
powershell -ExecutionPolicy Bypass -File tools\build_apk.ps1 -SkipPubGet
```

第一次运行时，如果依赖还没初始化，脚本会自动补一次依赖拉取；之后会按 `-SkipPubGet` 正常跳过。

APK 输出位置：

```text
build\app\outputs\flutter-apk\app-release.apk
```

完整构建说明见 [BUILD_APK.md](BUILD_APK.md)。

## 环境说明

仓库包含 Android Gradle Wrapper、构建脚本、依赖锁定文件、`android/local.properties.example` 和 `tools/build_env.local.ps1.example`。

仓库不包含 Flutter SDK、Android SDK、JDK、`dev_env/`、`android/local.properties` 和 `tools/build_env.local.ps1`。这些文件体积大或依赖本机路径，应按文档下载到本地相对目录，或用私有配置指定路径。

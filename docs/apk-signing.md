# APK 签名协作说明

## 背景

Android 覆盖安装要求同一个包名使用同一张签名证书。这个项目的包名是 `com.ipadboss.ipad_boss_app`。如果两台电脑各自生成或使用了不同的 `release-keystore.jks`，手机上安装新版 APK 时就会出现签名冲突，只能卸载旧包后再安装。

## 当前规则

项目现在不再从 `android/app/release-keystore.jks` 读取固定钥匙，也不在 Git 里保存真实签名文件或密码。

构建流程改为：

1. 每台电脑在本地保存同一份正式 keystore。
2. 每台电脑用 `tools/build_env.local.ps1` 配置 keystore 路径、alias 和密码。
3. `tools/build_apk.ps1` 生成 `android/local.properties`，把签名配置传给 Gradle。
4. 构建前强制校验证书 SHA256，防止用错钥匙打出无法覆盖安装的 APK。

正式签名证书 SHA256 必须是：

```text
84c43cb86f4c390aaa48f7af429828d4207680ac760a17d30cf0bf332734fa28
```

这把正式 keystore 已在当前电脑创建，默认位置是：

```text
D:\V881\padtest\dev_env\keys\ipad_boss_release.jks
```

另一台电脑不要重新生成 keystore，直接同步同一份 `ipad_boss_release.jks`，并用相同密码配置本机的 `tools/build_env.local.ps1`。

## 推荐目录

两台电脑都建议把正式 keystore 放在项目同级的 `dev_env` 下：

```text
workspace/
  dev_env/
    android-sdk/
    flutter/
    jdk-17.x/
    keys/
      ipad_boss_release.jks
  ipad_boss_app/
```

`dev_env/`、`*.jks`、`tools/build_env.local.ps1` 都不会提交到 Git。

## 本机配置

复制示例文件：

```powershell
Copy-Item tools\build_env.local.ps1.example tools\build_env.local.ps1
```

然后在 `tools/build_env.local.ps1` 中配置：

```powershell
$RepoRootForLocalEnv = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$LocalDevEnv = Join-Path $RepoRootForLocalEnv "..\dev_env"
$LocalFlutterSdk = Join-Path $LocalDevEnv "flutter"

$LocalReleaseKeystore = Join-Path $LocalDevEnv "keys\ipad_boss_release.jks"
$LocalReleaseKeyAlias = "boss"
$LocalReleaseStorePassword = "这里填写正式 keystore 密码"
$LocalReleaseKeyPassword = $LocalReleaseStorePassword
```

如果两台电脑路径不同，只需要改 `$LocalDevEnv` 或 `$LocalReleaseKeystore`，不要改 Git 里的项目文件。

## 构建

日常构建仍然使用：

```powershell
powershell -ExecutionPolicy Bypass -File tools\build_apk.ps1 -SkipPubGet
```

构建脚本会输出当前使用的 keystore 路径和证书 SHA256。只有 SHA256 和上面的正式指纹一致时才会继续打包。

## 常见问题

如果提示 `Release signing is incomplete`，说明本机还没有在 `tools/build_env.local.ps1` 里配置 keystore 路径或密码。

如果提示 `Release keystore SHA256 mismatch`，说明当前电脑使用的不是正式共享 keystore。不要继续绕过这个检查，否则打出来的 APK 可能无法覆盖安装到手机上。

如果正式 keystore 丢失，旧签名包无法再被同包名 APK 覆盖升级。只能确定一把新的正式 keystore，并让已安装旧签名包的测试手机先卸载旧包。

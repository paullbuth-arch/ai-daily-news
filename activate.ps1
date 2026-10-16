# xianyu-copilot 环境激活（pwsh 7）
#
# 工具链统一在 E:\personal\devtools，项目里不放工具链。
# 用法：. .\activate.ps1

$env:JAVA_HOME = "E:\personal\devtools\jdk-21"
$env:ANDROID_HOME = "E:\personal\devtools\android-sdk"
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME

# 关键：devtools\gradle-home 有 11GB 预热缓存（含 gradle-8.13-all 发行版），
# 不设这个会退回 ~/.gradle 从零下载。
$env:GRADLE_USER_HOME = "E:\personal\devtools\gradle-home"

Write-Host "[OK] xianyu-copilot 环境已激活"
Write-Host "     JAVA_HOME        = $env:JAVA_HOME"
Write-Host "     ANDROID_HOME     = $env:ANDROID_HOME"
Write-Host "     GRADLE_USER_HOME = $env:GRADLE_USER_HOME"

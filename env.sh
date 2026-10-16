#!/usr/bin/env bash
# xianyu-copilot 环境激活（bash / Git Bash）
#
# 工具链统一在 E:\personal\devtools，项目里不放工具链。
# 用法：source env.sh

export JAVA_HOME="E:/personal/devtools/jdk-21"
export ANDROID_HOME="E:/personal/devtools/android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"

# 关键：devtools\gradle-home 有 11GB 预热缓存（含 gradle-8.13-all 发行版），
# 不设这个会退回 ~/.gradle 从零下载。
export GRADLE_USER_HOME="E:/personal/devtools/gradle-home"

echo "[OK] xianyu-copilot 环境已激活"
echo "     JAVA_HOME        = $JAVA_HOME"
echo "     ANDROID_HOME     = $ANDROID_HOME"
echo "     GRADLE_USER_HOME = $GRADLE_USER_HOME"

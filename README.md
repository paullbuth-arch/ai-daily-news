# Android Vosk 蓝牙 SPP 语音识别 Demo

该项目演示 Android 手机如何通过双蓝牙 SPP 通道与 WuQi glass 设备交互：
- **控制通道 (UUID 0x1101)**：手机发送 VAD 控制命令（enable/start/stop）。
- **数据通道 (UUID 0x1102)**：glass 将 Opus 编码的语音数据推送给手机。

手机端使用 [Vosk](https://github.com/alphacep/vosk-api) 在本地进行中文语音识别。

## 功能

- 扫描并选择已配对的 glass 蓝牙设备。
- 连接控制通道，发送 `ENABLE_VAD`、`START_STREAMING_BY_SPP`、`STOP_STREAMING` 等命令。
- 连接数据通道，接收 Opus 编码音频并实时解码为 16 kHz / 16-bit / mono PCM。
- 使用 Vosk 进行本地中文语音识别。
- 支持将解码后的 PCM 录制为 WAV 文件。

## 音频格式

- 采样率：16 kHz
- 位深：16 bit
- 声道：单声道
- 编码：Opus（glass 端 `CONFIG_RECORDSV_ENCODER_OPUS=y`）
- 每个数据包包含 8 个 Opus 帧

## 项目结构

```
android_vosk_asr/
├── build.gradle.kts                              # 顶层构建脚本
├── settings.gradle.kts                           # 项目设置
├── gradle/wrapper/gradle-wrapper.properties    # Gradle Wrapper 配置
├── app/
│   ├── build.gradle.kts                          # 应用模块构建脚本
│   ├── proguard-rules.pro                        # ProGuard 规则
│   └── src/main/
│       ├── AndroidManifest.xml                   # 权限声明
│       ├── cpp/                                  # libopus + JNI
│       ├── java/com/example/voskasr/
│       │   ├── MainActivity.kt                   # Compose 入口
│       │   ├── audio/                            # OpusDecoder, PcmWavRecorder, VoskRecognizer
│       │   ├── bluetooth/                        # 蓝牙通道抽象
│       │   │   ├── control/                      # VAD 控制通道 (0x1101)
│       │   │   └── data/                         # VAD 数据通道 (0x1102)
│       │   ├── repository/                       # GlassAudioRepository
│       │   ├── viewmodel/                        # MainViewModel + MainUiState
│       │   ├── ui/                               # Compose UI
│       │   └── permission/                       # PermissionHelper
│       └── assets/model/                         # Vosk 中文模型
└── README.md                                     # 本文档
```

## 控制协议

手机 → glass（UUID 0x1101），每包 10 字节：

```
Offset  Size  Field
0       2     hdr = 0xEE08 (little-endian: 08 EE)
2       1     pkt_amount = 0
3       1     pkt_seq = 0
4       1     status_flag = 0x01
5       1     group_id = 0x07
6       1     cmd_id = 0x81(enable) / 0x82(disable) / 0x83(start) / 0x86(stop)
7       2     cmd_len = 10
9       1     checksum = sum(bytes 0..8) & 0xFF
```

glass → 手机 ack（UUID 0x1101），每包 10 字节：
- `hdr = 0xFF09`
- `status_flag = 0x01` 表示成功
- `cmd_id` 与请求一致

## 数据协议

glass → 手机（UUID 0x1102）：

```
[vad_id0_frame_header_t (14 bytes)][payload][1-byte checksum]
```

Frame header：
- `hdr = 0x09FF`
- `group_id = 0x07`
- `cmd_id = 0x8F` (VAD_PKT_VOICE_DATA)
- `cmd_len` = payload + 14 + 1
- `frame_sn`：包序号
- `frame_len`：payload 长度
- `block_cnt`：Opus 帧数量（通常为 8）

Payload = `block_cnt` x (`block_sn` 2 bytes + `block_len` 2 bytes + Opus data)

## 构建

### 环境

- Android Studio Ladybug 或更新版本
- JDK 21
- Android SDK 36 (Android 16 Baklava)
- Gradle 8.11.1

### 放置 Vosk 中文模型

将模型文件解压到：

```
app/src/main/assets/model/
```

目录结构示例：

```
am/final.mdl
conf/mfcc.conf
conf/model.conf
graph/...
ivector/...
README
```

### 编译

```bash
cd /home/ys/wq7036a/android_vosk_asr
./gradlew assembleDebug
```

APK 输出：

```
app/build/outputs/apk/debug/app-debug.apk
```

## 测试

1. 将 glass 与手机配对。
2. 安装 APK，授予蓝牙权限。
3. 打开 App，点击“连接设备”并选择 glass。
4. 连接成功后点击“开始推流”。
5. 对着 glass 说话，观察识别结果。
6. 点击“停止推流”结束。

## 依赖版本

- compileSdk / targetSdk: 36
- minSdk: 26
- Kotlin: 2.1.20
- Gradle: 8.11.1
- AGP: 8.7.2
- Compose BOM: 2025.02.00
- Vosk Android: 0.3.47

## 许可

本项目仅用于演示和学习目的。

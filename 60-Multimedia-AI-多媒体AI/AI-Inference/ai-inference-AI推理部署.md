# AI 推理部署

**一句话结论（20% 核心）**：嵌入式 AI 推理 = 在芯片上跑神经网络模型（图像识别、语音识别、唤醒词检测）。关键挑战：模型要小（几 MB）、推理要快（实时）、功耗要低（不烫手）。常用框架：TensorFlow Lite Micro、ONNX Runtime、裸写 C。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：把图书馆浓缩成一本小册子

- **训练（Training）** = 大学教授花几个月读完整个图书馆，写出一本知识总结（模型）
- **推理（Inference）** = 你拿着这本小册子，遇到问题查一下，秒出答案
- **模型量化** = 把"精确到小数点后 6 位"的知识总结，浓缩成"精确到整数"——准确度差不多，但书变薄了 4 倍

### 1.2 嵌入式 AI 的核心挑战和解决方案

| 挑战 | 解决方案 | 效果 |
|------|---------|------|
| 模型太大 | 量化（int8/float16） | 模型大小 ÷ 4 |
| 推理太慢 | 硬件加速（NPU/DSP） | 速度 ×10-100 |
| 功耗太高 | 专用芯片（HiFi5/NPU） | 能效比 ×50 |
| 内存不够 | 模型剪枝/蒸馏 | 参数减少 50-80% |

### 1.3 WQ7036AX 的 AI 角色

WQ7036AX 的 DCORE（HiFi5 DSP）负责：
- **KWS（Keyword Spotting，唤醒词检测）**：检测"你好小奇"等唤醒词，用的是轻量级神经网络模型
- **语音增强**：AI 降噪比传统 DSP 降噪效果好很多

### 1.4 如果只记得一件事

> 嵌入式 AI = 在芯片上跑小模型。量化压缩模型大小，NPU/DSP 加速推理。WQ7036AX 的 DCORE 用 HiFi5 DSP 跑 KWS 唤醒词检测。

---

## 第二层：实战理解

### 2.1 TensorFlow Lite Micro 最小示例

```c
// TFLite Micro 在 MCU 上跑推理
#include "tensorflow/lite/micro/micro_interpreter.h"

// 1. 加载模型（量化后的 int8 模型，几 KB 到几百 KB）
const unsigned char model_data[] = { /* ... */ };

// 2. 创建解释器
tflite::MicroInterpreter interpreter(model, resolver, tensor_arena, arena_size);

// 3. 输入数据（如音频特征）
float *input = interpreter.input(0);
input[0] = feature_0;
input[1] = feature_1;

// 4. 推理
interpreter.Invoke();

// 5. 读取输出（如唤醒词概率）
float *output = interpreter.output(0);
if (output[0] > 0.8) {
    // 检测到唤醒词
}
```

### 2.2 常见坑

| 问题 | 现象 | 根因 |
|------|------|------|
| 模型太大放不下 | 编译失败 | Flash 不够，需要量化或剪枝 |
| 推理太慢 | 实时性不满足 | 需要 DSP/NPU 加速，或优化算子 |
| 量化精度损失 | 准确率下降 | int8 量化后精度下降，需要重新校准 |

### 2.3 在 reGlasses 项目中怎么用

WQ7036AX 的 KWS 唤醒词检测在 `custom-kws/` 目录下，使用 HiFi5 DSP 加速。V881 可能有 NPU 用于更复杂的 AI 任务（如图像识别）。

---

## 第三层：延伸阅读

- [[computer-arch-mcu-计算机组成与MCU架构]] — HiFi5 DSP 为什么做 AI 推理快
- [[wq7036ax-audio-pipeline-WQ7036AX音频管道]] — KWS 在音频管道中的位置
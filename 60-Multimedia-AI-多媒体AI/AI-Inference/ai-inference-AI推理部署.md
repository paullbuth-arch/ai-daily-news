---
type: concept
tags: [AI推理, 嵌入式AI, KWS, 量化, DSP, 神经网络, 唤醒词]
aliases: [AI推理, 嵌入式AI, 边缘AI, 推理部署]
---

# AI 推理部署

## 一句话结论

嵌入式 AI 推理 = 在资源受限的芯片上跑神经网络模型。关键挑战：模型要小（Flash < 1MB）、推理要快（< 10ms）、功耗要低（< 10mW）。解决手段：量化（int8）、剪枝、硬件加速（DSP/NPU）。WQ7036AX 的 DCORE（HiFi5 DSP）跑 KWS 唤醒词检测，这是嵌入式 AI 最经典的落地场景。

## 30秒先看懂

1. 嵌入式 AI 分两步：训练在云端（GPU 集群，大模型），推理在芯片上（ARM/DSP/NPU，小模型）。
2. 神经网络推理的核心是矩阵乘法（乘加运算），DSP 有硬件 MAC（乘累加器），一个周期完成一次乘加，比通用 CPU 快 10-50 倍。
3. 量化（int8）是最常用的模型压缩手段——模型大小减为 1/4，推理速度提升 2-4 倍，精度损失仅 1-3%。
4. WQ7036AX 的 DCORE（HiFi5 DSP）跑 KWS 唤醒词检测：~200KB 模型，< 1ms 推理，可连续运行。
5. TensorFlow Lite Micro 是 MCU 上最常用的推理框架，通过 `tflite::MicroInterpreter` 加载模型并执行推理。

## 学完以后应该能做什么

### 第一遍
- 理解嵌入式 AI 推理的基本流程（输入 → 矩阵乘法 → 激活函数 → 输出）
- 理解量化（int8）的原理和效果（模型缩小 4 倍，速度提升 2-4 倍）
- 在 MCU 上使用 TensorFlow Lite Micro 运行简单模型
- 理解 KWS 唤醒词检测的架构

### 进阶
- 使用代表性数据集对模型进行量化校准
- 理解 DSP 硬件加速的原理（MAC、SIMD、零开销循环）
- 分析和优化模型的内存占用（tensor arena）
- 在 WQ7036AX 的 HiFi5 DSP 上部署自定义 KWS 模型

## 前置知识

- 基本的线性代数（矩阵乘法）
- C 语言编程
- 嵌入式系统基础（内存、Flash、CPU 架构）

## 术语先讲清楚

| 中文 | 英文 | 具体含义 |
|------|------|---------|
| 推理 | Inference | 使用训练好的神经网络模型对新数据进行预测 |
| 训练 | Training | 使用大量数据调整神经网络参数（权重）的过程 |
| 量化 | Quantization | 将浮点权重（float32）转换为整数（int8）以减少模型大小和加速推理 |
| 乘累加 | MAC (Multiply-Accumulate) | 神经网络的核心运算：`y = w * x + b`，DSP 一周期完成 |
| 唤醒词检测 | KWS (Keyword Spotting) | 在连续音频流中检测特定关键词的技术 |
| MFCC | Mel-Frequency Cepstral Coefficients | 音频特征提取方法，将音频转换为适合神经网络处理的特征向量 |
| 张量竞技场 | Tensor Arena | 推理时所有中间张量占用的内存区域 |
| 剪枝 | Pruning | 删除权重接近 0 的连接，减少计算量 |

## 第一层：费曼心智模型

### 类比：把图书馆浓缩成一本小册子

- **训练（Training）** = 大学教授花几个月读完整个图书馆，写出一本知识总结（模型文件，几百 MB）
- **推理（Inference）** = 你拿着这本小册子，遇到问题查一下，秒出答案（几 KB 到几 MB，实时运行）
- **量化（Quantization）** = 把"精确到小数点后 6 位"的知识总结，浓缩成"精确到整数"——准确度差不多，但书变薄了 4 倍

**为什么不在嵌入式芯片上训练？** 训练需要大量算力（GPU 集群）和大内存（几十 GB），嵌入式芯片根本放不下。所以训练在云端做，推理在芯片上做。

### 边界

- 嵌入式 AI 不是万能的：只能跑小模型（< 1MB），复杂任务（如大语言模型、高精度图像识别）需要云端
- 量化会损失精度：虽然通常只有 1-3%，但对某些任务（如医疗影像）可能不可接受
- DSP 加速需要特定的算子优化：不是所有神经网络层都能在 DSP 上高效运行（如某些激活函数）
- KWS 是嵌入式 AI 的"Hello World"——输入小、模型小、实时性要求高，非常适合入门

### 场景推演：语音唤醒

用户说"你好小镜"唤醒 Glasses：
1. 麦克风持续采集音频，DCORE 每 10ms 提取一次 MFCC 特征（40 维向量）
2. 将最近 20 帧（200ms）的 MFCC 特征拼接，形成 40×20 的输入特征图
3. 输入到 KWS 神经网络模型：全连接层 → ReLU → 全连接层 → Softmax
4. 输出 [0.92, 0.08]——92% 概率是唤醒词，8% 不是
5. 超过阈值 0.85，触发唤醒！DCORE 通知 ACORE 主控启动语音助手

整个过程 < 10ms，用户几乎感觉不到延迟。

## 第二层：原理/时序/约束

### 神经网络推理的四个步骤

```
① 输入 ──→ ② 矩阵乘法 ──→ ③ 激活函数 ──→ ④ 输出
(音频特征)   (权重×输入)    (ReLU/Softmax)   (概率结果)

一个简单的 KWS 模型：
输入: 40 个 MFCC 音频特征
  ↓ 全连接层 1 (40×64 权重矩阵)
  ↓ ReLU 激活
  ↓ 全连接层 2 (64×2 权重矩阵)
  ↓ Softmax
输出: [0.92, 0.08] → 92% 概率是唤醒词，8% 不是
```

**核心计算**：矩阵乘法。一个 40×64 的矩阵乘 64 维向量，需要 40×64 = 2560 次乘加运算。

### 嵌入式 AI 优化三板斧

| 手段 | 原理 | 效果 | 代价 |
|------|------|------|------|
| **量化（int8）** | 浮点权重 → 8-bit 整数 | 模型大小 ÷ 4，速度 ×2-4 | 精度损失 1-3% |
| **剪枝（Pruning）** | 删除接近 0 的权重 | 计算量减少 50-90% | 需要硬件支持稀疏计算 |
| **蒸馏（Distillation）** | 大模型教小模型 | 小模型接近大模型精度 | 需要大模型先训练好 |

### WQ7036AX 上的 KWS 架构

```
麦克风 → PDM → PCM → 特征提取(MFCC) → 神经网络推理 → 后处理
   │                    │                    │            │
   │                    │                    │            └─ 唤醒词检测到？
   │                    │                    └─ Dense + Softmax
   │                    └─ 40 维 MFCC，每 10ms 一帧
   └─ 16kHz 16bit 单声道
```

**KWS 模型特点**：输入很小（40 维特征），模型很小（~200KB 参数），推理很快（< 1ms），可以连续运行不费电。

### 模型量化实战

```python
# 在 PC 上做量化（训练完成后）
import tensorflow as tf

# 加载训练好的 float32 模型
model = tf.keras.models.load_model('kws_model.h5')

# 转换为 TFLite 格式 + int8 量化
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]

# 提供代表性数据集（用于校准量化参数）
def representative_dataset():
    for sample in calibration_data:
        yield [sample.astype(np.float32)]

converter.representative_dataset = representative_dataset
converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]

# 生成量化模型
quantized_model = converter.convert()
with open('kws_model_quantized.tflite', 'wb') as f:
    f.write(quantized_model)

# 模型大小对比：
# float32: ~800KB → int8: ~200KB
```

## 第三层：真实SDK代码

### WQ7036AX 上的 KWS 推理引擎

在 `/home/ys/wq7036a/custom-kws/` 中，KWS 唤醒词检测的完整实现：

```c
// 伪代码——WQ7036AX KWS 推理
// 文件路径: custom-kws/dcore/src/kws_infer.c

#include "tensorflow/lite/micro/micro_interpreter.h"
#include "tensorflow/lite/micro/all_ops_resolver.h"

// ① 模型数据（量化后的 int8 模型，编译进固件）
// 用 xxd -i 把 .tflite 文件转成 C 数组
const unsigned char kws_model_data[] = {
    #include "kws_model.cc"  // 约 200KB
};

// ② 分配推理所需的内存（tensor arena）
// KWS 模型通常需要 20-50KB 的 arena
constexpr int kTensorArenaSize = 50 * 1024;
static uint8_t tensor_arena[kTensorArenaSize];

// ③ 初始化
static tflite::AllOpsResolver resolver;
static tflite::MicroInterpreter *interpreter = nullptr;

void kws_init(void) {
    static tflite::Model *model = tflite::GetModel(kws_model_data);
    static tflite::MicroInterpreter static_interpreter(
        model, resolver, tensor_arena, kTensorArenaSize);
    interpreter = &static_interpreter;
    interpreter->AllocateTensors();
}

// ④ 推理：输入 MFCC 特征，输出唤醒词概率
float kws_infer(float *mfcc_features, int num_features) {
    // 填充输入 tensor
    float *input = interpreter->input(0)->data.f;
    for (int i = 0; i < num_features; i++) {
        input[i] = mfcc_features[i];
    }

    // 执行推理
    TfLiteStatus status = interpreter->Invoke();

    // 读取输出
    float *output = interpreter->output(0)->data.f;
    return output[0];  // 唤醒词的概率
}

// ⑤ 主循环：每 10ms 调用一次
void audio_callback(float *mfcc) {
    float score = kws_infer(mfcc, 40);
    if (score > 0.85) {
        trigger_wakeup();  // 检测到唤醒词！
    }
}
```

### HiFi5 DSP 算子优化

在 `/home/ys/wq7036a/custom-kws/dcore/src/` 中，针对 HiFi5 DSP 优化的算子：

```c
// 伪代码——HiFi5 DSP 优化的全连接层
// 利用 DSP 的硬件 MAC 进行向量化计算

// HiFi5 的 MAC 指令：一个周期完成一次乘加
// 比通用 CPU 快 10-50 倍
void dsp_fc_layer(const int8_t *input, const int8_t *weights,
                  int32_t *output, int in_dim, int out_dim) {
    for (int o = 0; o < out_dim; o++) {
        int32_t sum = 0;
        for (int i = 0; i < in_dim; i++) {
            // HiFi5 编译器会自动生成 MAC 指令
            sum += (int32_t)input[i] * (int32_t)weights[o * in_dim + i];
        }
        output[o] = sum;
    }
}
```

## 第四层：正常/异常路径

### 正常路径

```
音频输入 → MFCC 特征提取（40 维，每 10ms）
  → 特征拼接（20 帧 = 200ms 上下文）
  → 输入到神经网络 → 矩阵乘法 → ReLU → 矩阵乘法 → Softmax
  → 输出概率 → 阈值判断（0.85）
  → 低于阈值：继续监听
  → 高于阈值：触发唤醒！
```

### 异常路径

| 异常 | 现象 | 触发条件 | 恢复方式 |
|------|------|---------|---------|
| 模型太大 | 编译时 Flash 溢出 | 模型未量化或量化参数不对 | 量化到 int8，或减小模型 |
| 推理太慢 | 实时性不满足（>10ms） | 未启用 DSP 加速，或算子未优化 | 使用 HiFi5 优化算子库 |
| 量化精度损失 | 实际唤醒率下降 | 校准数据不够代表性 | 提供更多代表性校准数据 |
| Arena 不够大 | 推理时 crash | 中间 tensor 占用内存超过预期 | 逐步增大 arena size |
| 误唤醒 | 没有说唤醒词时被唤醒 | 阈值太低或模型过拟合 | 提高阈值，或重新训练模型 |
| 漏唤醒 | 说了唤醒词没反应 | 阈值太高或环境噪声大 | 降低阈值，或增加降噪预处理 |

## 第五层：调试方法

### 模型调试

```bash
# 查看模型结构
python3 -c "
import tensorflow as tf
model = tf.lite.Interpreter('kws_model_quantized.tflite')
model.allocate_tensors()
print('Input:', model.get_input_details())
print('Output:', model.get_output_details())
"

# 对比 float32 和 int8 模型输出差异
python3 -c "
import numpy as np
import tensorflow as tf

# 加载两个模型
float_model = tf.lite.Interpreter('kws_model_float32.tflite')
quant_model = tf.lite.Interpreter('kws_model_quantized.tflite')
# 用相同输入对比输出差异
"
```

### 推理性能分析

```c
// 在 WQ7036AX 上测量推理时间
uint32_t start = xthal_get_ccount();  // 读 DSP 时钟周期
interpreter->Invoke();
uint32_t end = xthal_get_ccount();
uint32_t cycles = end - start;
printf("Inference took %d cycles (%.2f ms at 400MHz)\n",
       cycles, cycles / 400000.0f);
```

### 内存占用分析

```bash
# 查看编译后的模型大小
arm-none-eabi-size build/acore/firmware.elf
# 查看 .rodata 段（模型数据存储在这里）
arm-none-eabi-objdump -h build/acore/firmware.elf | grep rodata
```

## 第六层：实战练习

### 练习1：模型量化对比

在 PC 上使用 TensorFlow 对一个小型 KWS 模型进行 int8 量化，对比量化前后的模型大小和推理输出差异。

```python
# 提示：
# 1. 训练或加载一个简单的 KWS 模型
# 2. 分别导出 float32 和 int8 的 TFLite 模型
# 3. 对比文件大小和输出精度
```

### 练习2：计算推理的计算量

给定一个 KWS 模型：输入层 40 维，全连接层 1 有 64 个神经元，全连接层 2 有 2 个神经元（输出）。计算：
1. 一次推理需要的乘加运算次数
2. 模型权重参数数量
3. 如果 DSP 以 400MHz 运行，每个 MAC 1 周期，理论最小推理时间是多少？

### 练习3：阅读真实源码——WQ7036AX KWS 实现

阅读 `/home/ys/wq7036a/custom-kws/dcore/` 目录下的源码，分析：
1. KWS 的初始化流程（`kws_init` 做了什么？）
2. 输入特征（MFCC）是如何提取的？参数是什么？
3. 推理结果是如何传递给 ACORE 的？（IPC 消息？共享内存？）
4. 如果模型推理失败，错误处理机制是什么？

## 自测与验收

1. 嵌入式 AI 推理和云端训练的分工是什么？为什么不在芯片上训练？
2. 量化（int8）的原理是什么？为什么模型大小可以减为 1/4，推理速度提升 2-4 倍？
3. 为什么 DSP 比通用 CPU 更适合神经网络推理？（MAC、SIMD、零开销循环）
4. KWS 模型为什么适合嵌入式部署？（模型大小、输入维度、推理时间）
5. 什么是 tensor arena？推理时如何估算 arena 大小？
6. 量化精度损失的主要原因是什么？如何减少精度损失？

## 延伸阅读

- [[computer-arch-mcu-计算机组成与MCU架构]] — HiFi5 DSP 为什么做 AI 推理快
- [[wq7036ax-audio-pipeline-WQ7036AX音频管道]] — KWS 在音频管道中的位置
- [[audio-system-音频系统基础]] — MFCC 特征提取的原理
- [[tensorflow-lite-micro-TFLite Micro部署]] — TFLite Micro 在 MCU 上的部署
- [[custom-kws-自定义唤醒词]] — 自定义 KWS 模型训练流程

## #flashcard

Q: 嵌入式 AI 推理和云端训练的分工？
A: 训练在云端（GPU 集群，大模型，大量数据），推理在芯片上（ARM/DSP/NPU，小模型，实时运行）。

Q: 量化（int8）的原理和效果？
A: 将 float32 权重映射到 int8 范围（-128 到 127），模型大小减为 1/4，速度提升 2-4 倍，精度损失 1-3%。

Q: 为什么 DSP 比 CPU 快？
A: DSP 有硬件 MAC（一周期完成乘加）、SIMD（单指令多数据）、零开销循环（循环不消耗指令周期）。

Q: KWS 模型的特点？
A: 输入小（40 维 MFCC），模型小（~200KB），推理快（< 1ms），可连续运行。

Q: 什么是 tensor arena？
A: 推理时所有中间张量占用的内存区域，需要在初始化时分配。大小由模型结构和输入尺寸决定。
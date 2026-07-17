# AI 推理部署

**一句话结论（20% 核心）**：嵌入式 AI 推理 = 在资源受限的芯片上跑神经网络模型。关键挑战：模型要小（Flash < 1MB）、推理要快（< 10ms）、功耗要低（< 10mW）。解决手段：量化（int8）、剪枝、硬件加速（DSP/NPU）。WQ7036AX 的 DCORE（HiFi5 DSP）跑 KWS 唤醒词检测，这是嵌入式 AI 最经典的落地场景。

---

## 第一层：核心认知（必须先看懂）

### 1.1 费曼类比：把图书馆浓缩成一本小册子

- **训练（Training）** = 大学教授花几个月读完整个图书馆，写出一本知识总结（模型文件，几百 MB）
- **推理（Inference）** = 你拿着这本小册子，遇到问题查一下，秒出答案（几 KB 到几 MB，实时运行）
- **量化（Quantization）** = 把"精确到小数点后 6 位"的知识总结，浓缩成"精确到整数"——准确度差不多，但书变薄了 4 倍

**为什么不在嵌入式芯片上训练？** 训练需要大量算力（GPU 集群）和大内存（几十 GB），嵌入式芯片根本放不下。所以训练在云端做，推理在芯片上做。

### 1.2 神经网络推理的四个步骤

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

**核心计算**：矩阵乘法。一个 40×64 的矩阵乘 64 维向量，需要 40×64 = 2560 次乘加运算。DSP 用硬件 MAC（乘累加器）一个周期完成一次乘加，比通用 CPU 快 10-50 倍。

### 1.3 嵌入式 AI 优化三板斧

| 手段 | 原理 | 效果 | 代价 |
|------|------|------|------|
| **量化（int8）** | 浮点权重 → 8-bit 整数 | 模型大小 ÷ 4，速度 ×2-4 | 精度损失 1-3% |
| **剪枝（Pruning）** | 删除接近 0 的权重 | 计算量减少 50-90% | 需要硬件支持稀疏计算 |
| **蒸馏（Distillation）** | 大模型教小模型 | 小模型接近大模型精度 | 需要大模型先训练好 |

### 1.4 WQ7036AX 上的 KWS 架构

```
麦克风 → PDM → PCM → 特征提取(MFCC) → 神经网络推理 → 后处理
   │                    │                    │            │
   │                    │                    │            └─ 唤醒词检测到？
   │                    │                    └─ Dense + Softmax
   │                    └─ 40 维 MFCC，每 10ms 一帧
   └─ 16kHz 16bit 单声道
```

**KWS 模型特点**：输入很小（40 维特征），模型很小（~200KB 参数），推理很快（< 1ms），可以连续运行不费电。

### 1.5 如果只记得一件事

> 嵌入式 AI = 云端训练 + 芯片推理。量化压缩模型（int8），DSP/NPU 加速推理。WQ7036AX 的 DCORE 跑 KWS 唤醒词检测，~200KB 模型，< 1ms 推理，连续运行。

---

## 第二层：实战理解

### 2.1 TensorFlow Lite Micro 在 MCU 上的完整流程

```c
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

### 2.2 模型量化实战

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

### 2.3 常见坑（附排查方法）

| 问题 | 现象 | 排查方法 | 根因 |
|------|------|---------|------|
| 模型太大 | 编译时 Flash 溢出 | `arm-none-eabi-size` 看 .rodata 段大小 | 模型未量化或量化参数不对 |
| 推理太慢 | 实时性不满足（>10ms） | 用定时器测量 Invoke() 耗时 | 没启用 DSP 加速，或算子未优化 |
| 量化精度损失 | 实际唤醒率下降 | 对比 float32 和 int8 模型的输出 | 校准数据不够代表性，或某些层对量化敏感 |
| arena 不够大 | 推理时 crash | 逐步增大 arena size 直到稳定 | 中间 tensor 占用内存超过预期 |

### 2.4 在 reGlasses 项目中怎么用

WQ7036AX 的 KWS 唤醒词检测代码在 `~/wq7036a/custom-kws/` 目录下。关键文件：
- 模型文件：训练好的 `.tflite` 模型，量化后编译进固件
- 特征提取：MFCC 特征提取在 DCORE 上运行
- 推理引擎：使用 HiFi5 DSP 优化的算子库

V881 可能有 NPU（神经网络处理器），用于更复杂的 AI 任务（如图像识别、人脸检测）。NPU 比 DSP 更快，但功耗也更高。

---

## 第三层：深入扩展

### 3.1 常见问题

- **为什么 KWS 不用云端识别？** 延迟和隐私。云端识别需要把音频发到服务器，延迟 200-500ms，而且涉及隐私。本地 KWS 延迟 < 10ms，音频不离开芯片。
- **DSP 为什么比 CPU 快？** DSP 有硬件 MAC（乘累加器）、SIMD（单指令多数据）、零开销循环。神经网络 90% 是乘加运算，DSP 一个周期完成一次，CPU 可能需要多个周期。
- **int8 量化为什么精度损失很小？** 神经网络对权重的小幅变化不敏感（鲁棒性）。int8 的 256 个级别足够表达权重的分布，校准过程会找到最优的缩放因子。

### 3.2 延伸阅读

- [[computer-arch-mcu-计算机组成与MCU架构]] — HiFi5 DSP 为什么做 AI 推理快
- [[wq7036ax-audio-pipeline-WQ7036AX音频管道]] — KWS 在音频管道中的位置
- [[audio-system-音频系统基础]] — MFCC 特征提取的原理
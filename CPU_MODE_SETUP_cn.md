# AMD 系统 CPU 模式设置指南

本指南解释了如何将 Maestro 配置为在纯 CPU 模式下运行，这对于没有 ROCm 支持的 AMD GPU 系统或 GPU 资源有限的系统特别有用。

## 快速入门

### 方法 1：使用环境变量

1. **创建您的 `.env` 文件**（如果尚未创建）：
   ```bash
   cp .env.example .env
   ```

2. **启用 CPU 模式**，将以下行添加到您的 `.env` 文件中：
   ```bash
   # 强制所有操作使用 CPU 模式
   FORCE_CPU_MODE=true
   
   # 可选：显式设置设备类型为 CPU
   PREFERRED_DEVICE_TYPE=cpu
   ```

3. **启动应用程序**：
   ```bash
   docker-compose up -d
   ```

### 方法 2：使用纯 CPU Docker Compose

我们提供了一个专用的纯 CPU Docker Compose 配置，不需要任何 GPU 驱动程序：

```bash
# 使用纯 CPU 配置
docker-compose -f docker-compose.cpu.yml up -d
```

此配置会自动设置 `FORCE_CPU_MODE=true` 并删除所有与 GPU 相关的设置。

## 硬件检测

系统现在包含自动硬件检测，支持：
- **带 CUDA 的 NVIDIA GPU**
- **带 ROCm 的 AMD GPU**（如果已安装）
- **带 Metal Performance Shaders 的 Apple Silicon**
- 任何系统的 **CPU 回退**

检测脚本 (`detect_gpu.sh`) 将自动识别您的硬件并相应地配置系统。

## 配置选项

### 环境变量

| 变量               | 描述           | 选项                      | 默认值   |
|--------------------|----------------|---------------------------|----------|
| `FORCE_CPU_MODE`   | 强制纯 CPU 操作 | `true`, `false`           | `false`  |
| `PREFERRED_DEVICE_TYPE` | 首选加速类型   | `auto`, `cuda`, `rocm`, `mps`, `cpu` | `auto`   |
| `CUDA_DEVICE`      | GPU 设备索引（如果使用 GPU） | `0`, `1`, `2` 等。 | `0`      |

### 硬件检测模块

新的 `hardware_detection.py` 模块提供：
- 自动设备选择
- 基于硬件优化的批处理大小
- CPU 线程优化
- 不同设备类型的内存管理

## 性能优化

在 CPU 模式下运行时，系统会自动：

1. **调整批处理大小** 以优化 CPU 处理
2. **根据可用 CPU 核心数设置线程计数**
3. **降低模型加载的内存要求**
4. **优化数据加载** 工作器

## AMD GPU 支持

### 带 ROCm（实验性）

如果您的系统安装了 ROCm，系统将尝试自动使用它。无需额外配置。

### 不带 ROCm

对于不带 ROCm 支持的 AMD GPU，请使用上述的 CPU 模式。这可在 AMD GPU 支持开发期间提供稳定的操作。

## 验证 CPU 模式

要验证 CPU 模式是否已激活，请检查启动日志：

```bash
docker compose logs backend | grep -i "cpu"
```

您应该会看到类似以下的消息：
- "CPU mode forced via FORCE_CPU_MODE environment variable"
- "Hardware Detection Results: Device Type: cpu"
- "Set PyTorch threads to X for CPU processing"

## 性能考量

### CPU 模式性能

- **嵌入生成** 将变慢（预计比 GPU 慢 5-20 倍）
- **文档处理** 对于大型 PDF 可能需要很长时间
- **重新排名** 操作的延迟将增加

### CPU 模式推荐设置

将这些添加到您的 `.env` 文件中以获得最佳 CPU 性能：

```bash
# 减少 CPU 处理的批处理大小
EMBEDDING_BATCH_SIZE=4
MAX_CONCURRENT_REQUESTS=2

# 根据您的 CPU 调整工作线程
MAX_WORKER_THREADS=8
```

## 故障排除

### 问题：内存不足错误

**解决方案**：减少批处理大小和并发操作：
```bash
EMBEDDING_BATCH_SIZE=2
MAX_CONCURRENT_REQUESTS=1
```

### 问题：处理缓慢

**解决方案**：确保您有足够的 CPU 核心和 RAM：
- 最低推荐：8 个 CPU 核心，16GB RAM
- 最佳：16 个以上 CPU 核心，32GB 以上 RAM

### 问题：Docker 仍然尝试使用 GPU

**解决方案**：使用纯 CPU Docker Compose 文件：
```bash
docker-compose -f docker-compose.cpu.yml up -d
```

## 社区贡献

CPU 模式的实现是在 AMD 系统用户的社区反馈下开发的。特别感谢 @palgrave 在 AMD CPU 优化方面的测试和反馈。

## 未来发展

我们正在努力：
- 原生 AMD ROCm 支持
- 进一步的 CPU 优化
- 支持 AMD 集成显卡 (APU)
- 基于硬件的自动性能调优

## 获取帮助

如果您在使用 CPU 模式时遇到问题：

1. 检查 [GitHub Issues](https://github.com/murtaza-nasir/maestro/issues)
2. 创建一个新问题，并提供：
   - 您的系统规格（CPU、RAM、操作系统）
   - 您看到的错误消息
   - 您的 `.env` 配置（删除敏感数据）
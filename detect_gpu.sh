#!/bin/bash

# 功能说明: GPU 检测脚本。该脚本用于检测系统是否可用 GPU，并识别当前运行平台（如 NVIDIA, AMD, macOS 或 CPU 模式）。

# 检测 GPU 是否可用以及我们所在的平台
detect_gpu() {
    # 检查是否通过环境变量强制使用 CPU 模式
    if [[ "${FORCE_CPU_MODE}" == "true" ]]; then
        echo "cpu_forced"
        return
    fi
    
    # 检查是否在 macOS 上
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS 不支持 NVIDIA Docker 运行时，但可能支持 Metal
        echo "mac"
        return
    fi
    
    # 在 Linux/Windows 上检查 NVIDIA GPU
    if command -v nvidia-smi &> /dev/null; then
        # 检查是否安装了 nvidia-container-toolkit
        if docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi &> /dev/null 2>&1; then
            echo "nvidia"
            return
        fi
        # 检测到 NVIDIA GPU 但 Docker 运行时不可用
        if nvidia-smi &> /dev/null; then
            echo "nvidia_no_docker"
            return
        fi
    fi
    
    # 检查是否支持 ROCm 的 AMD GPU
    if command -v rocm-smi &> /dev/null; then
        # 检查 ROCm 是否正确安装
        if rocm-smi --showid &> /dev/null; then
            echo "amd_rocm"
            return
        fi
    fi
    
    # 通过 lspci 检查 AMD GPU (回退检测)
    if command -v lspci &> /dev/null; then
        if lspci | grep -i "VGA.*AMD\|Display.*AMD" &> /dev/null; then
            echo "amd_detected"
            return
        fi
    fi
    
    # 未检测到 GPU 支持
    echo "cpu"
}

# 导出结果
GPU_SUPPORT=$(detect_gpu)
echo "GPU_SUPPORT=$GPU_SUPPORT"
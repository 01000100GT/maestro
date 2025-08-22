#!/bin/bash

# 功能说明: MAESTRO 启动脚本，包含自动 GPU 检测功能。该脚本用于启动 MAESTRO 应用程序及其所有依赖服务。

# Maestro 启动脚本，带自动 GPU 检测功能

set -e

echo "[START] 正在启动 Maestro..."

# 来源 GPU 检测
source ./detect_gpu.sh

# 导出 Docker Compose 的 GPU 可用性
if [ "$GPU_SUPPORT" = "nvidia" ]; then
    export GPU_AVAILABLE=true
    echo "[GPU] 检测到 NVIDIA GPU - 启用 GPU 支持"
    COMPOSE_FILES="-f docker-compose.yml -f docker-compose.gpu.yml"
else
    export GPU_AVAILABLE=false
    if [ "$GPU_SUPPORT" = "mac" ]; then
        echo "[信息] 检测到 macOS - 运行在 CPU 模式"
    else
        echo "[信息] 未检测到 GPU - 运行在 CPU 模式"
    fi
    COMPOSE_FILES="-f docker-compose.yml"
fi

# 检查 .env 文件是否存在
if [ ! -f .env ]; then
    echo "[警告] 未找到 .env 文件。正在从 .env.example 创建..."
    if [ -f .env.example ]; then
        cp .env.example .env
        echo "[确定] 已创建 .env 文件。请检查并更新设置。"
    else
        echo "[错误] 未找到 .env.example 文件。请创建 .env 文件。"
        exit 1
    fi
fi

# 来源环境变量
export $(grep -v '^#' .env | xargs)

# 检查镜像是否存在，如果需要则构建
echo "[检查] 正在检查 Docker 镜像..."
if ! docker images | grep -q "maestro-backend"; then
    echo "[构建] 正在为首次设置构建 Docker 镜像..."
    docker compose $COMPOSE_FILES build
    echo "[构建] 正在构建 CLI 镜像..."
    docker compose build cli
else
    # 检查 CLI 镜像是否存在
    if ! docker images | grep -q "maestro-cli"; then
        echo "[构建] 正在构建 CLI 镜像..."
        docker compose build cli
    fi
fi

# 启动服务
echo "[DOCKER] 正在启动 Docker 服务..."
docker compose $COMPOSE_FILES up -d

# 检查服务是否正在运行
sleep 5
if docker compose ps | grep -q "Up"; then
    echo "[确定] Maestro 正在运行!"
    echo ""
    echo "[访问] 访问 MAESTRO 地址:"
    # 如果新的 nginx 代理端口可用，则使用，否则回退到旧配置以实现向后兼容
    if [ -n "${MAESTRO_PORT}" ]; then
        if [ "${MASTRO_PORT}" = "80" ]; then
            echo "         http://localhost"
        else
            echo "         http://localhost:${MAESTRO_PORT}"
        fi
    else
        # 向后兼容
        echo "         前端: http://${FRONTEND_HOST:-localhost}:${FRONTEND_PORT:-3030}"
        echo "         后端 API: http://${BACKEND_HOST:-localhost}:${BACKEND_PORT:-8001}"
    fi
    echo ""
    echo "[状态] GPU 可用: ${GPU_AVAILABLE}"
    echo ""
    echo "[注意] 重要 - 首次运行:"
    echo "       首次启动需要 5-10 分钟下载 AI 模型"
    echo "       通过以下命令监控进度: docker compose logs -f maestro-backend"
    echo "       等待消息: Application startup complete"
else
    echo "[错误] 启动服务失败。请查看日志: docker compose logs"
    exit 1
fi
#!/bin/bash

# 功能说明: MAESTRO 关闭脚本。该脚本用于停止 MAESTRO 应用程序及其所有依赖服务。

# Maestro 关闭脚本

echo "🛑 正在停止 Maestro..."

# 引入 GPU 检测脚本以确定使用了哪些 compose 文件
source ./detect_gpu.sh

if [ "$GPU_SUPPORT" = "nvidia" ]; then
    COMPOSE_FILES="-f docker-compose.yml -f docker-compose.gpu.yml"
else
    COMPOSE_FILES="-f docker-compose.yml"
fi

# 停止服务
docker compose $COMPOSE_FILES down

echo "✅ Maestro 已停止。"
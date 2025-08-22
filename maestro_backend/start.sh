#!/bin/bash

# 功能说明: MAESTRO 后端启动脚本。此脚本负责初始化数据库、运行必要的迁移（如果适用），然后启动 FastAPI 服务器。

# MAESTRO 后端启动脚本
# 该脚本在启动 FastAPI 服务器之前初始化数据库并运行迁移

echo "🚀 正在启动 MAESTRO 后端..."

# 等待 PostgreSQL 准备就绪
echo "⏳ 正在等待 PostgreSQL 准备就绪..."
for i in {1..30}; do
    python -c "
from database.database import test_connection
if test_connection():
    print('✅ PostgreSQL 已准备就绪!')
    exit(0)
" && break
    echo "正在等待 PostgreSQL... ($i/30)"
    sleep 2
done

# 如果需要，初始化 PostgreSQL 数据库
if [[ "$DATABASE_URL" == postgresql* ]]; then
    echo "🐘 正在初始化 PostgreSQL 数据库..."
    python -m database.init_postgres
    
    if [ $? -eq 0 ]; then
        echo "✅ PostgreSQL 初始化完成!"
    else
        echo "⚠️  PostgreSQL 初始化出现问题 (可能已初始化)"
    fi
fi

# 跳过迁移 - PostgreSQL 模式通过 SQL 文件管理
echo "📊 正在跳过迁移 (PostgreSQL 模式通过 SQL 文件管理)"

# 启动 FastAPI 服务器
echo "🌐 正在启动 FastAPI 服务器..."
# 将 LOG_LEVEL 转换为小写以用于 uvicorn
UVICORN_LOG_LEVEL=$(echo "${LOG_LEVEL:-error}" | tr '[:upper:]' '[:lower:]')
exec uvicorn main:app --host 0.0.0.0 --port 8000 --reload --log-level $UVICORN_LOG_LEVEL --timeout-keep-alive 1800 --timeout-graceful-shutdown 1800
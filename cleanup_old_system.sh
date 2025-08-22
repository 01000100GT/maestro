#!/bin/bash

# 功能说明: 旧文档系统清理脚本。该脚本用于删除所有旧的数据库和向量存储文件，以准备新的系统部署。

# 旧文档系统清理脚本
# 该脚本删除所有旧数据库和向量存储文件

echo "=== 正在清理旧文档系统 ==="

# 首先停止应用程序
echo "正在停止 docker 容器..."
docker-compose down

# 删除旧的 SQLite 数据库
echo "正在删除旧的 SQLite 数据库..."
rm -f data/maestro.db
rm -f data/maestro.db-journal
rm -f data/maestro.db-wal

# 删除旧的向量存储
echo "正在删除旧的 ChromaDB 向量存储..."
rm -rf maestro_backend/ai_researcher/data/vector_store/

# 删除已处理的文件
echo "正在删除已处理的文件..."
rm -rf maestro_backend/ai_researcher/data/processed/

# 删除旧的向量存储封装文件
echo "正在删除旧的向量存储封装文件..."
cd maestro_backend/ai_researcher/core_rag/

# 只保留基本文件
rm -f vector_store.py
rm -f vector_store_direct.py
rm -f vector_store_factory.py
rm -f vector_store_manager.py
rm -f vector_store_manager_original.py
rm -f vector_store_original.py
rm -f vector_store_original.py.bak
rm -f vector_store_safe.py
rm -f vector_store_safe_original.py
rm -f vector_store_with_lock.py

cd ../../..

# 删除所有迁移文件，因为我们正在从头开始
echo "正在删除旧的迁移文件..."
rm -f maestro_backend/database/migrations/*.py
# 如果存在，保留 __init__.py
touch maestro_backend/database/migrations/__init__.py

echo "=== 清理完成 ==="
echo "准备从头开始构建新系统"
# Maestro 数据库管理与重置指南

## 概述

本指南涵盖了 Maestro 应用程序的数据库管理工具，包括完整的数据库重置和双数据库架构下的文档一致性管理。

## ⚠️ 重要提示：数据同步

**所有数据库必须一起重置！** Maestro 系统使用三个紧密耦合的存储系统：

1. **主数据库** (`maestro_backend/data/maestro.db`) - 用户账户、聊天、文档记录
2. **AI 数据库** (`ai_researcher/data/processed/metadata.db`) - 提取的文档元数据
3. **向量存储** (`ai_researcher/data/vector_store/`) - 文档嵌入和分块

**为什么要一起重置？**
- 文档 ID 必须在所有数据库中匹配
- 孤立数据会导致搜索失败和用户界面不一致
- 部分重置会损坏文档处理流程

## 用法（推荐 - 使用 Maestro CLI）

最简单的方法是使用扩展的 Maestro CLI：

### 1. 检查当前数据库状态
```bash
./maestro-cli.sh reset-db --stats
```

### 2. 检查数据一致性
```bash
./maestro-cli.sh reset-db --check
```

### 3. 重置所有数据库（带备份）
```bash
./maestro-cli.sh reset-db --backup
```

### 4. 强制重置（跳过确认）
```bash
./maestro-cli.sh reset-db --force
```

### 5. 获取帮助
```bash
./maestro-cli.sh reset-db --help
```

## 文档一致性管理工具

除了完整的数据库重置，MAESTRO 还包含了用于维护双数据库架构中文档一致性的专用工具。

### CLI 文档一致性工具

对于精细的文档管理，请使用 CLI 一致性工具：

#### 单个文档操作
```bash
# 检查所有系统中特定文档的一致性
python maestro_backend/cli_document_consistency.py check-document <doc_id> <user_id>

# 清理特定孤立文档
python maestro_backend/cli_document_consistency.py cleanup-document <doc_id> <user_id>
```

#### 用户级别操作
```bash
# 检查特定用户的所有文档
python maestro_backend/cli_document_consistency.py check-user <user_id>

# 清理用户的所有孤立文档
python maestro_backend/cli_document_consistency.py cleanup-user <user_id>
```

#### 系统范围操作
```bash
# 获取整体系统一致性状态
python maestro_backend/cli_document_consistency.py system-status

# 执行全系统范围的孤立文档清理
python maestro_backend/cli_document_consistency.py cleanup-all
```

### 自动一致性监控

MAESTRO 包含自动运行的内置监控：

- **频率**：每 60 分钟（可配置）
- **范围**：所有用户和文档类型
- **操作**：自动清理孤立文件和旧的失败文档
- **日志记录**：详细记录发现和解决的问题

### 何时使用这些工具

- **数据库重置**：完全重新开始，删除所有数据
- **一致性工具**：有针对性的清理，保留有效数据
- **自动监控**：持续维护，防止出现问题

在以下情况选择一致性工具：
- 修复特定文档问题而不丢失其他数据
- 清理由于处理失败产生的孤立文件
- 在不完全重置的情况下验证系统完整性
- 在不停机的情况下执行维护

## 手动使用（Docker 命令）

如果您偏爱手动控制：

### 1. 启动后端容器
```bash
docker compose up -d backend
```

### 2. 复制重置脚本
```bash
docker cp reset_databases.py maestro-backend:/app/
```

### 3. 在容器内运行重置
```bash
# 检查统计信息
docker exec -it maestro-backend python reset_databases.py --stats

# 检查一致性
docker exec -it maestro-backend python reset_databases.py --check

# 带备份重置
docker exec -it maestro-backend python reset_databases.py --backup

# 强制重置
docker exec -it maestro-backend python reset_databases.py --force
```

### 4. 清理
```bash
docker exec maestro-backend rm /app/reset_databases.py
```

## 重置内容

### 1. 主数据库
- 所有用户账户（迁移后重新创建的除外）
- 聊天会话和消息
- 文档记录和处理作业
- 写作会话和草稿
- **操作**：数据库文件被删除并重新创建，使用全新的 schema

### 2. AI 研究员数据库
- 文档元数据（标题、作者、年份、期刊等）
- 处理时间戳
- **操作**：数据库文件被删除（在第一个文档处理后重新创建）

### 3. 向量存储 (ChromaDB)
- 密集嵌入 (BGE-M3, 1024 维度)
- 稀疏嵌入 (30,000 维度)
- 带元数据的文档分块
- **操作**：整个目录被删除（在第一个文档处理后重新创建）

### 4. 文档文件
- 原始 PDF (`ai_researcher/data/raw_pdfs/`)
- 转换后的 Markdown (`ai_researcher/data/processed/markdown/`)
- 提取的元数据 JSON (`ai_researcher/data/processed/metadata/`)
- **操作**：目录内容被清除

## 重置后

### 1. 重启 Docker 容器（推荐）
```bash
docker compose down
docker compose up -d
```

### 2. 重新创建用户账户
```bash
./maestro-cli.sh create-user researcher password123 --full-name "Research User"
```

### 3. 重新上传文档
```bash
./maestro-cli.sh ingest researcher ./pdfs
```

### 4. 验证一切正常
```bash
./maestro-cli.sh reset-db --stats
./maestro-cli.sh reset-db --check
```

## 备份与恢复

### 自动备份
使用 `--backup` 标志会在 `./backups/` 中创建带时间戳的备份：
- `maestro.db.20240808_143022.backup`
- `metadata.db.20240808_143022.backup`
- `vector_store_20240808_143022_backup/`

### 手动备份（重置前）
```bash
# 备份主数据库
docker exec maestro-backend cp /app/data/maestro.db /app/maestro_backup.db

# 将备份文件从容器中复制出来
docker cp maestro-backend:/app/maestro_backup.db ./maestro_backup.db
```

### 从备份恢复
```bash
# 停止容器
docker compose down

# 恢复主数据库
docker cp ./maestro_backup.db maestro-backend:/app/data/maestro.db

# 启动容器
docker compose up -d
```

## 故障排除

### 容器未运行
```bash
# 启动后端
docker compose up -d backend

# 检查状态
docker compose ps
```

### 权限错误
```bash
# 检查 Docker 权限
docker info

# 如果需要，使用 sudo 运行
sudo ./maestro-cli.sh reset-db --stats
```

### 检测到数据不一致
如果 `--check` 显示不一致，这表明：
- 之前未完成的文档处理
- 手动修改数据库
- 处理过程中系统崩溃

**解决方案**：运行完全重置以恢复一致性：
```bash
./maestro-cli.sh reset-db --backup
```

### 重置失败
如果重置中途失败：
1. 检查 Docker 容器日志：`docker compose logs backend`
2. 手动完成重置：`docker compose down && docker volume rm maestro_maestro-data`
3. 重新启动：`docker compose up -d`

## 最佳实践

### 开发
- 开发期间频繁重置数据库
- 始终使用 `--backup` 标志以确保安全
- 在重大更改后检查一致性

### 生产
- **切勿**在没有完整备份的情况下在生产环境中运行重置
- 在生产部署前测试恢复程序
- 定期安排一致性检查

### 调试
1. 始终先运行 `--check` 以识别问题
2. 使用 `--stats` 了解当前状态
3. 启用日志记录：`docker compose logs -f backend`

## 文件位置参考

### Docker 容器内部
```
/app/
├── data/maestro.db                     # 主数据库
└── ai_researcher/data/
    ├── vector_store/                   # ChromaDB 集合
    ├── raw_pdfs/                       # 原始 PDF
    ├── processed/
    │   ├── markdown/                   # 转换后的文档
    │   ├── metadata/                   # 提取的元数据 JSON
    │   └── metadata.db                 # AI 研究员数据库
```

### 主机系统（挂载）
```
maestro/
├── maestro_backend/data/maestro.db     # 主数据库（绑定挂载）
└── (maestro-data volume)/              # AI 研究员数据（Docker 卷）
```

## 相关文档

- [数据库架构](docs/DATABASE_ARCHITECTURE.md) - 完整系统架构
- [CLAUDE.md](CLAUDE.md) - AI 助手参考
- [数据库 README](maestro_backend/database/README.md) - 数据库模块指南
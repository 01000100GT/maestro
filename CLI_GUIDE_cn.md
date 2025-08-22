# MAESTRO 命令行界面 (CLI) 指南

MAESTRO CLI 提供了强大的命令行工具，用于批量文档处理、用户管理和系统管理。CLI 具有**直接处理**功能，可提供实时进度反馈，绕过后台队列系统，实现即时结果。

## 快速入门

MAESTRO 为不同平台提供了方便的包装脚本：

### Linux/macOS
```bash
# 使脚本可执行（仅首次）
chmod +x maestro-cli.sh

# 显示可用命令
./maestro-cli.sh help

# 示例：创建用户并摄取文档
./maestro-cli.sh create-user researcher mypass123
./maestro-cli.sh ingest researcher ./documents
```

### Windows PowerShell
```powershell
# 显示可用命令
.\maestro-cli.ps1 help

# 示例：创建用户并摄取文档
.\maestro-cli.ps1 create-user researcher mypass123
.\maestro-cli.ps1 ingest researcher .\documents
```

### Windows 命令提示符
```cmd
REM 显示可用命令
maestro-cli.bat help

REM 示例：创建用户并摄取文档
maestro-cli.bat create-user researcher mypass123
maestro-cli.bat ingest researcher .\documents
```

## 主要功能

- **直接处理**：文档立即处理并提供实时反馈
- **实时进度**：查看每个处理步骤和时间戳
- **无队列**：绕过后台处理器以获得即时结果
- **多格式支持**：处理 PDF、Word (docx, doc) 和 Markdown (md, markdown) 文件
- **GPU 控制**：指定用于处理的 GPU 设备
- **灵活组织**：文档添加到用户库，可以组织到组中
- **自动清理**：成功处理后删除源文件的选项

## 可用命令

### 用户管理

#### create-user
创建新的用户帐户。

```bash
./maestro-cli.sh create-user <username> <password> [options]
```

**选项：**
- `--full-name "Name"`：设置用户的全名
- `--admin`：创建管理员用户

**示例：**
```bash
# 创建普通用户
./maestro-cli.sh create-user researcher mypass123 --full-name "Research User"

# 创建管理员用户
./maestro-cli.sh create-user admin adminpass --admin --full-name "Administrator"
```

#### list-users
列出系统中的所有用户（仅限管理员）。

```bash
./maestro-cli.sh list-users
```

### 文档组管理

#### create-group
创建文档组以组织文档。

```bash
./maestro-cli.sh create-group <username> <group_name> [options]
```

**选项：**
- `--description "Description"`：添加组的描述

**示例：**
```bash
./maestro-cli.sh create-group researcher "AI Papers" --description "Machine Learning Research"
```

#### list-groups
列出文档组。

```bash
./maestro-cli.sh list-groups [options]
```

**选项：**
- `--user <username>`：仅列出特定用户的组

**示例：**
```bash
# 列出所有组（管理员视图）
./maestro-cli.sh list-groups

# 列出特定用户的组
./maestro-cli.sh list-groups --user researcher
```

### 文档处理

#### ingest
直接处理文档并提供实时反馈。这是向 MAESTRO 添加文档的主要命令。

```bash
./maestro-cli.sh ingest <username> <document_directory> [options]
```

**选项：**
- `--group <group_id>`：将文档添加到特定组
- `--force-reembed`：强制重新处理现有文档
- `--device <device>`：指定 GPU 设备（例如，cuda:0, cuda:1, cpu）
- `--delete-after-success`：成功处理后删除源文件
- `--batch-size <num>`：控制并行处理（默认值：5）

**支持的文件类型：**
- PDF 文件 (`.pdf`)
- Word 文档 (`.docx`, `.doc`)
- Markdown 文件 (`.md`, `.markdown`)

**示例：**
```bash
# 基本摄取（文档添加到用户库）
./maestro-cli.sh ingest researcher ./documents

# 添加到特定组
./maestro-cli.sh ingest researcher ./documents --group abc123-def456

# 使用特定 GPU 处理
./maestro-cli.sh ingest researcher ./documents --device cuda:0

# 强制重新处理并在成功后删除
./maestro-cli.sh ingest researcher ./documents --force-reembed --delete-after-success

# 使用更大的批处理大小以加快处理速度
./maestro-cli.sh ingest researcher ./documents --batch-size 10
```

**处理流程：**
1. 验证文档目录并计算支持的文件
2. 将文档转换为 Markdown 格式
3. 提取元数据（标题、作者、年份、期刊）
4. 将文档分块为重叠的段落
5. 使用 BGE-M3 模型生成嵌入
6. 存储在 ChromaDB 向量存储和元数据数据库中
7. 显示实时进度，每个步骤都带有时间戳

#### status
检查文档处理状态。

```bash
./maestro-cli.sh status [options]
```

**选项：**
- `--user <username>`：检查特定用户的状态
- `--group <group_id>`：检查特定组的状态

**示例：**
```bash
# 检查所有文档（管理员视图）
./maestro-cli.sh status

# 检查特定用户的状态
./maestro-cli.sh status --user researcher

# 检查特定组的状态
./maestro-cli.sh status --user researcher --group abc123-def456
```

#### cleanup
删除处理失败或具有特定状态的文档。此命令可帮助您通过删除无法成功处理的文档来清理数据库。

```bash
./maestro-cli.sh cleanup [options]
```

**选项：**
- `--user <username>`：仅清理特定用户的文档
- `--status <status>`：以此状态为目标文档（默认值：“failed”）
- `--group <group_id>`：仅清理特定组中的文档
- `--confirm`：跳过确认提示

**作用：**
1. 查找所有符合您条件的文档
2. 显示将要删除内容的摘要
3. 请求确认（除非使用 --confirm）
4. 删除数据库记录
5. 从磁盘中删除相关文件

**示例：**
```bash
# 清理所有失败的文档（请求确认）
./maestro-cli.sh cleanup --status failed

# 清理失败的文档，无需确认
./maestro-cli.sh cleanup --status failed --confirm

# 清理特定用户的错误文档
./maestro-cli.sh cleanup --user researcher --status error

# 清理特定组中失败的文档
./maestro-cli.sh cleanup --group abc123 --status failed
```

#### cleanup-cli
删除在 CLI 处理过程中卡住的文档。当您中断文档摄取（例如按 Ctrl+C）并且文档处于“cli_processing”状态时，这很有用。

```bash
./maestro-cli.sh cleanup-cli [options]
```

**选项：**
- `--dry-run`：显示将要删除的内容，但不实际删除任何内容
- `--force`：跳过确认提示

**作用：**
1. 查找所有卡在“cli_processing”状态的文档
2. 显示每个卡住文档的详细信息
3. 计算将要释放的总磁盘空间
4. 请求确认（除非使用 --force）
5. 删除文档和所有相关文件：
   - 原始上传文件
   - 生成的 markdown 文件
   - 向量存储嵌入
   - 文档组关联

**示例：**
```bash
# 检查哪些文档卡住了（空运行）
./maestro-cli.sh cleanup-cli --dry-run

# 清理卡住的文档（请求确认）
./maestro-cli.sh cleanup-cli

# 强制清理，无需确认
./maestro-cli.sh cleanup-cli --force
```

**何时使用每个命令：**
- 当文档处理失败并且您想删除它们时，使用 `cleanup`
- 当您中断 CLI 摄取并且文档卡住时，使用 `cleanup-cli`

### 文档搜索

#### search
搜索特定用户的文档。

```bash
./maestro-cli.sh search <username> <query> [options]
```

**选项：**
- `--limit <num>`：限制结果数量（默认值：10）

**示例：**
```bash
./maestro-cli.sh search researcher "machine learning" --limit 5
```

### 数据库管理

#### reset-db
重置所有数据库和文档文件。**重要提示**：所有数据库必须一起重置以保持数据一致性。

```bash
./maestro-cli.sh reset-db [options]
```

**选项：**
- `--backup`：在重置前创建带时间戳的备份
- `--force`：跳过确认提示（危险！）
- `--stats`：仅显示数据库统计信息（不重置）
- `--check`：仅检查数据库之间的数据一致性

**将要重置的内容：**
- 主应用程序数据库（用户、聊天、文档）
- AI 研究员数据库（提取的元数据）
- ChromaDB 向量存储（嵌入和分块）
- 所有文档文件（PDF、markdown、元数据）

**示例：**
```bash
# 显示当前数据库统计信息
./maestro-cli.sh reset-db --stats

# 检查数据一致性
./maestro-cli.sh reset-db --check

# 带备份重置
./maestro-cli.sh reset-db --backup

# 强制重置，无需确认（危险！）
./maestro-cli.sh reset-db --force
```

## 直接 Docker 命令

对于高级用户，您还可以直接使用 Docker Compose 运行 CLI 命令：

```bash
# 一般格式
docker compose --profile cli run --rm cli python cli_ingest.py [command] [options]

# 示例
docker compose --profile cli run --rm cli python cli_ingest.py create-user myuser mypass
docker compose --profile cli run --rm cli python cli_ingest.py list-groups
docker compose --profile cli run --rm cli python cli_ingest.py ingest myuser GROUP_ID /app/pdfs
```

## 目录结构

使用 CLI 时，文档应放置在适当的目录中：

```
maestro/
├── documents/       # 所有文档类型的推荐目录
├── pdfs/           # 传统目录（仍受支持）
└── ...
```

CLI 脚本会自动将您的本地目录映射到容器路径：
- `./documents` → `/app/documents`
- `./pdfs` → `/app/pdfs`

## 提示和最佳实践

1. **文档组织**：在摄取文档之前创建组，以便更好地组织
2. **批量处理**：使用 `--batch-size` 控制内存使用和处理速度
3. **GPU 选择**：对于多 GPU 系统，使用 `--device` 指定 GPU
4. **错误恢复**：使用 `cleanup` 命令删除失败的文档，然后重新处理
5. **定期备份**：在重要操作之前使用 `reset-db --backup`

## 故障排除

### 常见问题

**Docker 未运行：**
```bash
# 启动 Docker 服务
docker compose up -d backend
```

**权限被拒绝：**
```bash
# 使脚本可执行
chmod +x maestro-cli.sh
```

**内存不足：**
```bash
# 减小批处理大小
./maestro-cli.sh ingest user ./docs --batch-size 2
```

**GPU 不可用：**
```bash
# 使用 CPU 处理
./maestro-cli.sh ingest user ./docs --device cpu
```

### 获取帮助

有关任何命令的详细帮助：
```bash
./maestro-cli.sh help
./maestro-cli.sh <command> --help
```

## 性能考量

- **批处理大小**：批处理大小越大，处理速度越快，但内存使用量也越大
- **GPU 与 CPU**：GPU 处理嵌入速度快 10-20 倍
- **文档大小**：大型 PDF 可能需要几分钟才能处理
- **网络**：首次运行下载模型（约 2GB），后续运行使用缓存
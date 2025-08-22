# MAESTRO 故障排除指南

## 常见问题与解决方案

### 登录问题

#### 问题：无法使用 admin/admin123 登录
**症状**：尽管使用了正确的凭据，但出现“用户名或密码不正确”错误

**解决方案**：重置管理员密码
```bash
# 运行重置脚本（已在容器中）
docker exec -it maestro-backend python reset_admin_password.py

# 或使用自定义密码：
docker exec -it maestro-backend python reset_admin_password.py YourNewPassword

# 或使用环境变量：
docker exec -it maestro-backend bash -c "ADMIN_PASSWORD=YourNewPassword python reset_admin_password.py"
```

**替代方案**：完全重置数据库（警告：会删除所有数据！）
```bash
docker compose down -v
docker compose up -d
```

---

### Windows/WSL 问题

#### 问题：后端无法启动 - “bad interpreter”错误
**症状**：`/bin/bash^M: bad interpreter: No such file or directory`

**解决方案**：修复行尾
```powershell
# 运行行尾修复脚本
.\fix-line-endings.ps1

# 重建并重启
docker compose down
docker compose build --no-cache maestro-backend
docker compose up -d
```

#### 问题：GPU 错误阻止启动
**症状**：`nvidia-container-cli: initialization error: WSL environment detected but no adapters were found`

**解决方案**：使用纯 CPU 模式
```powershell
# 在 Windows 上始终使用 CPU Compose 文件
docker compose -f docker-compose.cpu.yml up -d

# 对于所有 Docker 命令：
docker compose -f docker-compose.cpu.yml logs -f
docker compose -f docker-compose.cpu.yml down
```

---

### ⏱ 启动问题

#### 问题：启动后立即登录失败
**症状**：前端加载但登录返回“网络错误”或“无法登录”

**解释**：首次运行时，后端会下载 AI 模型（5-10 分钟）

**解决方案**：等待启动完成
```bash
# 监控后端日志
docker compose logs -f maestro-backend

# 等待此消息：
# "INFO:     Application startup complete."
```

---

### CPU 与 GPU 模式

#### 何时使用 CPU 模式：
- 没有 NVIDIA GPU 的系统
- 没有 ROCm 支持的 AMD GPU
- 开发/测试环境

#### 如何启用 CPU 模式：

**选项 1：使用纯 CPU 的 compose 文件**（推荐）
```bash
docker compose -f docker-compose.cpu.yml up -d
```

**选项 2：设置环境变量**
```bash
# 在您的 .env 文件中：
FORCE_CPU_MODE=true

# 然后使用常规 compose：
docker compose up -d
```

---

### AI/LLM 处理问题

#### 问题：规划/大纲生成错误
**症状**：
- 使用规划代理时在大纲生成或规划阶段出现错误
- LLM 上下文长度超出错误
- 规划阶段超时错误
- 来自本地 LLM 的“请求过大”错误

**常见原因**：
- 具有较小上下文窗口（8K-32K token）的本地 LLM
- 处理包含数百个笔记的广泛研究
- 针对云 LLM（例如通过 openrouter）优化的默认设置不适用于本地模型

**解决方案 1：通过设置减少规划上下文**
1. 导航到设置（屏幕左下角）
2. 转到“研究参数”选项卡
3. 找到“内容处理限制”部分
4. 将“规划上下文”从默认的 200,000 个字符减少：
   - 对于具有 8K 上下文的本地 LLM：设置为 30,000-40,000
   - 对于具有 16K 上下文的本地 LLM：设置为 60,000-80,000
   - 对于具有 32K 上下文的本地 LLM：设置为 100,000-120,000
5. 保存设置

**解决方案 2：调整其他相关参数**
```yaml
# 在“设置”→“研究参数”中，还应考虑调整：

Note Content Limit: 15000  # (默认值：32000)
- 减少单个笔记窗口的大小

Writing Preview: 10000  # (默认值：30000)
- 减少写作过程中显示给写作代理的上下文

Max Notes per Section: 20  # (默认值：40)
- 限制分配给每个部分的笔记数量
```

**理解设置**：
- **规划上下文**：一次传递给规划代理的笔记的最大字符数
- **笔记内容限制**：从每个搜索结果中提取的内容窗口大小
- **写作预览**：显示给写作代理作为上下文的先前内容量
- 这些设置协同工作 - 同时减少所有三个设置可为本地 LLM 提供最佳结果

#### 问题：研究代理内存问题
**症状**：
- 研究阶段内存不足错误
- 文档处理期间容器崩溃
- “CUDA 内存不足”错误

**解决方案**：减少并发操作和批处理大小
```bash
# 在“设置”→“研究参数”中：
Concurrent Requests: 2  # (默认值：10)
Max Research Cycles/Section: 1  # (默认值：2)

# 对于文档处理，在 .env 中：
EMBEDDING_BATCH_SIZE=4  # (默认值：32)
MAX_WORKER_THREADS=2  # (默认值：10)
```

---

### 数据库问题

#### 问题：数据库连接错误
**症状**：`could not translate host name "postgres" to address`

**解决方案**：确保 PostgreSQL 容器正在运行
```bash
# 检查容器状态
docker compose ps

# 如果 postgres 未运行：
docker compose up -d postgres

# 等待其健康，然后启动其他服务：
docker compose up -d
```

#### 问题：数据库损坏
**解决方案**：重置数据库（警告：会删除所有数据！）
```bash
docker compose down -v
docker volume rm maestro_postgres-data maestro_maestro-data
docker compose up -d
```

---

### 网络访问问题

#### 问题：无法从其他设备访问
**解决方案**：配置网络访问
```bash
# 使用网络选项重新运行设置
./setup-env.sh  # 选择选项 2（网络）

# 或手动编辑 .env：
CORS_ALLOWED_ORIGINS=http://YOUR_IP,http://localhost

# 重启服务
docker compose down
docker compose up -d
```

#### 问题：CORS 错误
**解决方案**：清除浏览器缓存并重建
```bash
docker compose down
docker compose up --build -d
```

---

### Docker 问题

#### 问题：“卷正在使用中”错误
**解决方案**：强制删除容器和卷
```bash
# 停止所有服务
docker compose down

# 删除特定容器
docker rm -f maestro-backend maestro-frontend maestro-nginx maestro-postgres

# 删除卷
docker volume rm maestro_postgres-data maestro_maestro-data

# 全新启动
docker compose up -d
```

---

### 调试命令

#### 检查容器状态：
```bash
docker compose ps
```

#### 查看特定服务日志：
```bash
docker compose logs backend
docker compose logs postgres
docker compose logs frontend
```

#### 检查数据库用户：
```bash
docker exec -it postgres psql -U maestro_user -d maestro_db -c "SELECT id, username, email FROM users;"
```

#### 测试后端健康状况：
```bash
curl http://localhost:8000/health
```

#### 访问后端 shell：
```bash
docker exec -it maestro-backend bash
```

---

### 获取帮助

如果这些解决方案无法解决您的问题：

1. **收集诊断信息：**
```bash
# 保存日志
docker compose logs > maestro-logs.txt

# 系统信息
docker version > system-info.txt
docker compose version >> system-info.txt
```

2. **报告问题：**
- GitHub Issues：https://github.com/murtaza-nasir/maestro.git
- 包括：
  - 错误消息
  - 日志文件
  - 重现步骤
  - 您的操作系统和 Docker 版本

---

### 完全重置

如果所有方法都失败，请执行完全重置：

```bash
# 停止并删除所有内容
docker compose down -v --remove-orphans

# 删除所有 maestro 镜像
docker images | grep maestro | awk '{print $3}' | xargs docker rmi -f

# 清理 Docker 系统
docker system prune -a --volumes

# 克隆新的存储库
cd ..
rm -rf maestro
git clone https://github.com/murtaza-nasir/maestro.git
cd maestro

# 全新启动
./setup-env.sh  # 或 Windows 上的 setup-env.ps1
docker compose up -d
```

---

## 平台特定说明

### Windows

- 始终使用 `docker-compose.cpu.yml` 以避免 GPU 问题
- 以管理员身份运行 PowerShell 以执行 Docker 命令
- PowerShell 脚本使用 `.\script.ps1` 语法

### macOS

- 纯 CPU 模式是自动的（不支持 GPU）
- 可能需要增加 Docker Desktop 内存分配

### Linux

- 完全支持 GPU，带 nvidia-container-toolkit
- 确保用户在 `docker` 组中以避免 `sudo`

---

最后更新：2025-08-18
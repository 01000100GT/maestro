# MAESTRO Windows 设置指南

本指南将帮助您在 Windows 系统上设置和运行 MAESTRO。

## 先决条件

### 1. 适用于 Windows 的 Docker Desktop
- 下载并安装 [适用于 Windows 的 Docker Desktop](https://www.docker.com/products/docker-desktop/)
- 确保 Docker Desktop 正在运行并配置为 Windows 容器
- 在命令提示符或 PowerShell 中运行 `docker --version` 验证安装

### 2. 适用于 Windows 的 Git
- 下载并安装 [适用于 Windows 的 Git](https://git-scm.com/download/win)
- 确保 Git 已添加到您的系统 PATH

### 3. PowerShell（推荐）
- Windows 10/11 附带 PowerShell 5.1 或更高版本
- 为了更好的体验，请考虑安装 [PowerShell 7](https://github.com/PowerShell/PowerShell/releases)

## 安装步骤

### 1. 克隆存储库
```powershell
# 使用 PowerShell（推荐）
git clone https://github.com/murtaza-nasir/maestro.git
cd maestro

# 或使用命令提示符
git clone https://github.com/murtaza-nasir/maestro.git
cd maestro
```

### 2. 环境设置

#### 选项 A：PowerShell 脚本（推荐）
```powershell
# 运行 PowerShell 设置脚本
.\setup-env.ps1
```
此脚本将自动：
- 将 `.env.example` 复制到 `.env`
- 生成安全密码
- 配置网络设置
- 设置 GPU 配置

#### 选项 B：手动设置
```powershell
# 复制环境模板
copy .env.example .env

# 使用您偏好的文本编辑器编辑 .env 文件
notepad .env
```

### 3. 启动 MAESTRO

#### 对于配备 NVIDIA GPU 的系统
```powershell
# 启动所有服务
docker compose up -d

# 查看日志
docker compose logs -f

# 停止服务
docker compose down
```

#### 对于纯 CPU 系统（推荐给大多数 Windows 用户）
```powershell
# 使用针对 CPU 优化的 compose 文件
docker compose -f docker-compose.cpu.yml up -d

# 查看日志
docker compose -f docker-compose.cpu.yml logs -f

# 停止服务
docker compose -f docker-compose.cpu.yml down
```

#### 使用单个命令
```powershell
# 构建并启动后端
docker compose up -d backend

# 构建并启动前端
docker compose up -d frontend

# 启动文档处理器
docker compose up -d doc-processor
```

## CLI 操作

MAESTRO 提供 Windows 兼容的 CLI 工具用于文档管理：

### 使用 PowerShell 脚本（推荐）
```powershell
# 显示帮助
.\maestro-cli.ps1 help

# 创建用户
.\maestro-cli.ps1 create-user researcher mypass123 -FullName "Research User"

# 创建文档组
.\maestro-cli.ps1 create-group researcher "AI Papers" -Description "Machine Learning Research"

# 处理 PDF 文档
.\maestro-cli.ps1 ingest researcher ./pdfs

# 检查状态
.\maestro-cli.ps1 status -Username researcher

# 搜索文档
.\maestro-cli.ps1 search researcher "machine learning" -Limit 10
```


## 配置

### 环境变量

主配置文件是 `.env`，从 `.env.example` 创建。主要设置包括：

#### 基本配置
```env
# 主应用程序端口（您唯一需要配置的端口）
MAESTRO_PORT=80  # 如果端口 80 正在使用，请更改此项
```

```env
# 时区配置
TZ=America/Chicago
VITE_SERVER_TIMEZONE=America/Chicago
```

```env
# 管理员凭据（请更改这些！）
ADMIN_USERNAME=admin
ADMIN_PASSWORD=admin123  # 为安全起见必须更改
```

```env
# JWT 密钥（生成一个安全的随机字符串）
JWT_SECRET_KEY=your-secret-key-change-this
```

#### GPU 配置
```env
# 用于 GPU 加速（仅限 NVIDIA GPU）
BACKEND_GPU_DEVICE=0
DOC_PROCESSOR_GPU_DEVICE=0
CLI_GPU_DEVICE=0
```

```env
# 用于纯 CPU 模式（无 GPU 或 AMD GPU）
FORCE_CPU_MODE=true  # 取消注释以禁用 GPU
```

#### 数据库配置
```env
# PostgreSQL 设置（由设置脚本自动配置）
POSTGRES_USER=maestro_user
POSTGRES_PASSWORD=secure_generated_password
POSTGRES_DB=maestro_db
```

### GPU 支持

要在 Windows 上启用 GPU 加速：

1. 安装 [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)
2. 在 `.env` 中设置 GPU 设备 ID：
   ```env
   BACKEND_GPU_DEVICE=0
   DOC_PROCESSOR_GPU_DEVICE=0
   CLI_GPU_DEVICE=0
   ```
3. 使用 `all` 以使用所有可用 GPU

## 故障排除

### 常见问题

#### 1. 行尾问题（Windows 的关键问题）
```powershell
# 如果您看到“bad interpreter”或类似错误：
.\\fix-line-endings.ps1

# 然后重建后端：
docker compose down
docker compose build --no-cache maestro-backend
docker compose up -d
```

#### 2. Docker 未运行
```powershell
# 检查 Docker 状态
docker --version
docker compose version

# 如果 Docker Desktop 未运行，请启动它
# 打开 Docker Desktop 应用程序
```

#### 3. 端口冲突
如果端口 80 正在使用：
```powershell
# 检查什么正在使用端口 80
netstat -ano | findstr :80

# 在 .env 文件中更改端口
MAESTRO_PORT=8080  # 或任何可用端口
```

#### 4. 权限问题
```powershell
# 如果需要，以管理员身份运行 PowerShell
# 或调整项目目录的文件权限
```

#### 5. 路径问题
```powershell
# 在路径中使用正斜杠或转义反斜杠
PDF_DIR=./pdfs
# 或
PDF_DIR=.\\pdfs
```

#### 6. 脚本执行策略
如果 PowerShell 脚本无法运行：
```powershell
# 检查执行策略
Get-ExecutionPolicy

# 设置执行策略（以管理员身份运行）
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 日志和调试

#### 查看服务日志
```powershell
# 所有服务
docker compose logs -f

# 特定服务
docker compose logs -f backend
docker compose logs -f frontend
docker compose logs -f doc-processor
```

#### 调试 CLI 操作
```powershell
# 运行 CLI 并输出详细信息
docker compose --profile cli run --rm cli python cli_ingest.py --help
```

## 文件结构

```
maestro/
├── maestro-cli.ps1          # Windows PowerShell CLI 脚本
├── setup-env.ps1            # Windows PowerShell 设置脚本
├── fix-line-endings.ps1     # Windows 行尾修复脚本
├── .env.example             # 包含所有选项的环境模板
├── .env                     # 您的环境配置（从 .env.example 创建）
├── docker-compose.yml       # 主 Docker 服务配置
├── docker-compose.cpu.yml   # 纯 CPU 配置
├── maestro_backend/
│   ├── data/                # 持久数据存储
│   └── Dockerfile           # 后端容器定义
├── maestro_frontend/
│   └── Dockerfile           # 前端容器定义
├── nginx/                   # 反向代理配置
│   └── nginx.conf           # 路由规则
└── reports/                 # 生成的研究报告
```

## 性能优化

### Windows 特定优化

1. **Docker Desktop 设置**：
   - 增加内存分配（推荐：8GB+）
   - 增加 CPU 分配（推荐：4 核+）
   - 启用 WSL 2 后端以获得更好的性能

2. **文件系统性能**：
   - 将项目存储在快速存储（推荐 SSD）上
   - 使用 Windows 路径并正确转义

3. **网络配置**：
   - 使用 `127.0.0.1` 而不是 `localhost` 以获得更好的性能
   - 如果需要，配置防火墙例外

## 安全注意事项

1. **环境变量**：
   - 切勿将 `.env` 文件提交到版本控制
   - 在生产环境中使用强 JWT 密钥
   - 确保 API 密钥安全

2. **网络安全**：
   - 在生产环境中使用 HTTPS/WSS
   - 配置适当的防火墙规则
   - 考虑使用 VPN 进行远程访问

3. **文件权限**：
   - 限制对敏感目录的访问
   - 使用适当的文件权限

## 支持

如需额外帮助：

1. 查看主 [README.md](README.md) 获取一般信息
2. 查看 [TROUBLESHOOTING.md](TROUBLESHOOTING.md) 获取常见问题和解决方案
3. 查看 [DOCKER.md](DOCKER.md) 获取 Docker 特定详细信息
4. 查看 [USER_GUIDE.md](USER_GUIDE.md) 获取详细配置说明
5. 在 [GitHub](https://github.com/murtaza-nasir/maestro/issues) 上提交问题以报告错误或提出功能请求

## Windows 特定说明

- **行尾**：适用于 Windows 的 Git 会自动处理行尾转换
- **路径分隔符**：在配置文件中使用正斜杠 (`/`)
- **文件权限**：Windows 处理文件权限的方式与 Unix 系统不同
- **性能**：Docker Desktop 中的 WSL 2 后端比 Hyper-V 提供更好的性能
- **防病毒软件**：某些防病毒软件可能会干扰 Docker 操作；如果需要，请添加例外
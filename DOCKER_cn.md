# MAESTRO Docker 设置

本文档提供了有关如何使用 Docker 运行 MAESTRO 的详细说明。有关快速入门，请参阅 [README.md](./README.md) 文件中的 Docker 安装说明。

本指南解释了如何使用 Docker 运行 MAESTRO，这提供了一种在不直接在系统上安装依赖项的情况下设置和使用应用程序的简便方法。

## 先决条件

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/)（通常包含在 Docker Desktop 中）
- **GPU 支持（推荐）**：为了 RAG 功能获得最佳性能
  - 支持 CUDA 的 NVIDIA GPU
  - 已安装 [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)

## 快速入门

1. 克隆存储库：
   ```bash
   git clone https://github.com/murtaza-nasir/maestro.git
   cd maestro
   ```

2. 配置您的环境变量：

   **快速设置（推荐）：**
   ```bash
   ./setup-env.sh
   ```

   **手动设置：**
   ```bash
   cp .env.example .env
   nano .env  # 使用您的 API 密钥和网络设置进行编辑
   ```

   根目录中的 `.env` 文件自动处理所有网络配置。API URL 是根据您的主机/端口设置动态构建的。

3. 为您的 PDF 创建一个目录（用于 CLI 摄取）：
   ```bash
   mkdir -p pdfs
   ```
   
   将您要分析的任何 PDF 文件复制到 `pdfs` 目录中。

4. 启动 MAESTRO Web 应用程序：
   ```bash
   docker compose up
   ```

   这将构建 Docker 镜像并启动 Web 界面，可通过 http://localhost:3030 访问

## 环境配置

MAESTRO 使用灵活的环境配置系统，支持各种部署场景：

### 配置文件

- **`.env.example`**：包含所有可用选项和示例的模板
- **`.env`**：您的实际配置（从模板创建）
- **`setup-env.sh`**：用于引导配置的交互式设置脚本

### 网络配置

系统根据您的网络设置自动构建 API URL：

```bash
# .env 配置示例
BACKEND_HOST=localhost          # 后端运行位置
BACKEND_PORT=8001              # 后端端口
FRONTEND_HOST=localhost        # 前端运行位置
FRONTEND_PORT=3030            # 前端端口
API_PROTOCOL=http             # http 或 https
WS_PROTOCOL=ws               # ws 或 wss

# 自动构建：
# VITE_API_HTTP_URL=http://localhost:8001
# VITE_API_WS_URL=ws://localhost:8001
```

### 部署场景

**本地开发：**
```bash
BACKEND_HOST=localhost
FRONTEND_HOST=localhost
API_PROTOCOL=http
WS_PROTOCOL=ws
```

**生产（同一服务器）：**
```bash
BACKEND_HOST=0.0.0.0
FRONTEND_HOST=0.0.0.0
API_PROTOCOL=https
WS_PROTOCOL=wss
```

**分布式部署：**
```bash
# 后端服务器 .env
BACKEND_HOST=0.0.0.0
BACKEND_PORT=8001

# 前端服务器 .env
BACKEND_HOST=api.yourdomain.com
FRONTEND_HOST=0.0.0.0
API_PROTOCOL=https
WS_PROTOCOL=wss
```

有关完整的部署文档，请参阅 [DEPLOYMENT.md](./DEPLOYMENT.md)。

## GPU 支持

MAESTRO 的 RAG 功能（文档嵌入、检索和重新排名）显著受益于 GPU 加速。Docker 设置默认包含 GPU 支持。

### GPU 支持要求

1. 支持 CUDA 的 NVIDIA GPU
2. 您的主机系统上已安装 NVIDIA 驱动程序
3. 已安装 NVIDIA Container Toolkit

### 验证 GPU 支持

启动容器后，您可以验证 GPU 访问：

```bash
docker compose exec backend nvidia-smi
```

如果看到您的 GPU 列出，则容器已成功访问您的 GPU。

### 配置 GPU 使用

默认情况下，容器使用 GPU 设备 3。您可以通过修改 `docker-compose.yml` 中的 `device_ids` 来更改此设置：

```yaml
deploy:
  resources:
    reservations:
      devices:
        - driver: nvidia
          device_ids: ['0']  # 改用 GPU 0
          capabilities: [gpu]
```

如果您没有 GPU 或不想使用它，请注释掉 `docker-compose.yml` 中与 GPU 相关的部分。

## 目录结构

Docker 设置创建了几个挂载卷以持久化数据：

- `./.env`：您的配置文件
- `./pdfs`：将您的 PDF 文件放在此处用于 CLI 摄取
- `./reports`：研究报告的输出目录
- `maestro-data`：用于向量存储和处理数据的 Docker 卷
- `./maestro_model_cache`：Hugging Face 嵌入模型缓存（约 2GB）
- `./maestro_datalab_cache`：文档处理模型缓存（约 3GB）

## 模型缓存和性能优化

MAESTRO 使用了几个 AI 模型，它们会在首次使用时自动下载：

### 模型类型和大小

- **嵌入模型** (BAAI/bge-m3)：约 2GB - 用于语义搜索和文档检索
- **文档处理模型** (marker-pdf)：约 3GB - 用于 PDF 文本提取、布局分析和表格识别
- **重新排名模型**：约 500MB - 用于提高搜索结果相关性

### 持久缓存

Docker Compose 配置包括持久卷挂载，用于在容器重启之间缓存模型：

```yaml
volumes:
  - ./maestro_model_cache:/root/.cache/huggingface      # 嵌入模型
  - ./maestro_datalab_cache:/root/.cache/datalab       # 文档处理模型
```

### 首次运行与后续运行

**首次运行：**
- 模型自动下载（总计约 5GB）
- 首次文档处理需要 2-3 分钟
- 需要稳定的互联网连接

**后续运行：**
- 模型立即从缓存加载
- 文档处理立即开始
- 模型加载不需要互联网

### 管理模型缓存

**查看缓存大小：**
```bash
du -sh maestro_model_cache maestro_datalab_cache
```

**清除缓存（如果需要）：**
```bash
rm -rf maestro_model_cache maestro_datalab_cache
docker compose down
docker compose up --build
```

**备份缓存（用于离线部署）：**
```bash
tar -czf maestro-models-cache.tar.gz maestro_model_cache maestro_datalab_cache
```

### 性能优势

启用持久缓存后：
- ✅ **启动更快**：首次运行后无需下载模型
- ✅ **带宽减少**：模型只需下载一次
- ✅ **离线操作**：无需互联网即可处理文档
- ✅ **一致性能**：可预测的处理时间
- ✅ **资源效率**：容器重启之间无需重复下载

## 命令行界面 (CLI)

MAESTRO 包含一个强大的 CLI，用于批量文档摄取和管理。有关完整的 CLI 文档，请参阅 [CLI_GUIDE.md](./CLI_GUIDE.md)。

### 快速 CLI 示例

```bash
# Linux/macOS
./maestro-cli.sh help
./maestro-cli.sh create-user researcher mypass123
./maestro-cli.sh ingest researcher ./documents

# Windows PowerShell
.\maestro-cli.ps1 help
.\maestro-cli.ps1 create-user researcher mypass123
.\maestro-cli.ps1 ingest researcher .\documents
```

CLI 提供直接文档处理和实时进度更新，支持 PDF、Word 和 Markdown 文件。有关以下内容，请参阅 [CLI 指南](./CLI_GUIDE.md)：
- 完整命令参考
- 用户和组管理
- 文档摄取选项
- 数据库管理工具
- 故障排除提示


## 使用 Web 界面

使用 MAESTRO 的主要方式是通过 Web 界面：

1. 启动应用程序：
   ```bash
   docker compose up
   ```

2. 打开浏览器并访问 http://localhost:3030

3. 创建账户或登录

4. 通过 Web 界面上传文档或使用 CLI 进行批量操作

5. 创建研究任务和写作会话

## 故障排除

### GPU 问题

如果您遇到与 GPU 相关的问题：

1. 验证您的 NVIDIA 驱动程序已安装并正常工作：
   ```bash
   nvidia-smi
   ```

2. 检查 NVIDIA Container Toolkit 是否已正确安装：
   ```bash
   sudo docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi
   ```

3. 如果您没有 GPU 或无法使其正常工作，请修改 `docker-compose.yml` 以禁用 GPU 支持。

### 权限问题

如果您遇到挂载卷的权限问题：

```bash
sudo chown -R $(id -u):$(id -g) ./reports ./pdfs
```

### 容器无法启动

如果容器无法启动：

1. 检查日志：
   ```bash
   docker compose logs backend
   docker compose logs frontend
   docker compose logs doc-processor
   ```

2. 验证您的 `.env` 文件是否配置正确。

3. 尝试重建镜像：
   ```bash
   docker compose build --no-cache
   ```

### CLI 问题

如果 CLI 命令失败：

1. 确保后端服务正在运行：
   ```bash
   docker compose up -d backend
   ```

2. 检查数据库是否可访问：
   ```bash
   docker compose --profile cli run --rm cli python cli_ingest.py list-users
   ```

3. 验证 `pdfs` 目录的文件权限：
   ```bash
   ls -la ./pdfs
   ```

### 反向代理超时问题

如果您在反向代理（如 nginx、Apache 或云负载均衡器）后面运行 MAESTRO，并在长时间操作（搜索、文档处理等）期间遇到 504 网关超时错误，您需要增加反向代理配置中的超时设置。

#### 对于 nginx：

将这些设置添加到您的 nginx 服务器块或位置块：

```nginx
# 增加长时间运行操作的超时设置
proxy_connect_timeout 600s;
proxy_send_timeout 600s;
proxy_read_timeout 600s;
send_timeout 600s;

# WebSocket 支持实时更新
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";

# 推荐的缓冲区设置
proxy_buffering on;
proxy_buffer_size 4k;
proxy_buffers 8 4k;
proxy_busy_buffers_size 8k;

# 可选：增加大型文档上传的最大正文大小
client_max_body_size 100M;
```

#### 对于 Apache：

将这些设置添加到您的 VirtualHost 或 ProxyPass 配置中：

```apache
# 增加长时间操作的超时时间
ProxyTimeout 600
Timeout 600

# 对于 WebSocket 支持
RewriteEngine On
RewriteCond %{HTTP:Upgrade} websocket [NC]
RewriteCond %{HTTP:Connection} upgrade [NC]
RewriteRule ^/?(.*) "ws://localhost:8000/$1" [P,L]
```

#### 对于 nginx Proxy Manager (GUI)：

如果使用 nginx Proxy Manager：
1. 转到您的代理主机设置
2. 单击“高级”选项卡
3. 添加上述自定义 nginx 配置
4. 保存并测试

#### 对于云负载均衡器：

- **AWS ALB/ELB**：在负载均衡器属性中将空闲超时设置为 600 秒
- **Google Cloud Load Balancer**：将后端服务超时配置为 600 秒
- **Azure Application Gateway**：将后端设置中的请求超时设置为 600 秒

**注意**：大多数反向代理的默认超时时间为 60 秒，这对于 MAESTRO 的 AI 驱动操作来说太短了，这些操作可能需要几分钟才能完成。应用程序会优雅地处理这些超时，但增加限制可以提供更好的用户体验。

## 高级配置

### 持久存储

所有数据都存储在 Docker 卷和挂载目录中，确保您的数据在容器重启之间持久存在。

### 资源限制

如果需要，您可以将资源限制添加到 `docker-compose.yml` 文件中：

```yaml
services:
  backend:
    # ... 现有配置 ...
    deploy:
      resources:
        limits:
          cpus: '4'
          memory: 8G
```

## 安全注意事项

- 在生产环境中立即更改默认密码
- 为用户账户使用强密码
- 考虑使用环境变量进行敏感配置
- 定期更新 Docker 镜像
- 通过 Web 界面监控访问日志

## 性能提示

- 使用 GPU 加速以获得更好的嵌入性能
- 如果内存充足，请增加批量操作的批量大小
- 使用 `docker stats` 监控资源使用情况
- 考虑为向量数据库使用 SSD 存储
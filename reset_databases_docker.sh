# 功能说明: MAESTRO 数据库重置脚本（适用于 Docker）。此脚本在 Docker 容器内部执行数据库重置操作，以确保所有数据库的数据一致性，并支持备份、强制执行、统计和检查等选项。

#!/bin/bash

# Maestro 数据库重置脚本 (适用于 Docker)
# 该脚本在 Docker 容器内部运行重置，其中数据库实际存在

set -e

# 输出颜色代码
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # 无颜色

echo -e "${CYAN}============================================================${NC}"
echo -e "${CYAN}       Maestro 数据库重置工具 (Docker)${NC}"
echo -e "${CYAN}============================================================${NC}"
echo

# 解析命令行参数
BACKUP=false
FORCE=false
STATS=false
CHECK=false

for arg in "$@"
do
    case $arg in
        --backup)
            BACKUP=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --stats)
            STATS=true
            shift
            ;;
        --check)
            CHECK=true
            shift
            ;;
        --help)
            echo "用法: $0 [OPTIONS]"
            echo "选项:"
            echo "  --backup  重置前创建备份"
            echo "  --force   跳过确认提示"
            echo "  --stats   仅显示数据库统计信息"
            echo "  --check   检查数据库之间的数据一致性"
            echo "  --help    显示此帮助消息"
            exit 0
            ;;
        *)
            echo -e "${RED}未知选项: $arg${NC}"
            echo "使用 --help 获取用法信息"
            exit 1
            ;;
    esac
done

# 检查 Docker 是否正在运行
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}错误: Docker 未运行或您没有访问它的权限${NC}"
    echo "请启动 Docker 或使用适当的权限运行 (例如, sudo)"
    exit 1
fi

# 检查后端容器是否存在
if ! docker ps -a --format '{{.Names}}' | grep -q '^maestro-backend$'; then
    echo -e "${RED}错误: 未找到 maestro-backend 容器${NC}"
    echo "请确保 Maestro 应用程序已通过以下命令部署:"
    echo "  docker compose up -d"
    exit 1
fi

# 复制重置脚本到容器
echo -e "${BLUE}正在复制重置脚本到 Docker 容器...${NC}"
docker cp reset_databases.py maestro-backend:/app/reset_databases.py

# 根据参数构建命令
CMD="python /app/reset_databases.py"
if [ "$BACKUP" = true ]; then
    CMD="$CMD --backup"
fi
if [ "$FORCE" = true ]; then
    CMD="$CMD --force"
fi
if [ "$STATS" = true ]; then
    CMD="$CMD --stats"
fi
if [ "$CHECK" = true ]; then
    CMD="$CMD --check"
fi

# 在容器内部执行重置脚本
echo -e "${BLUE}正在 Docker 容器内部运行重置脚本...${NC}"
echo

# 检查容器是否正在运行
if docker ps --format '{{.Names}}' | grep -q '^maestro-backend$'; then
    # 容器正在运行，使用 exec
    docker exec -it maestro-backend $CMD
else
    # 容器存在但未运行，使用 run
    echo -e "${YELLOW}后端容器未运行。正在启动临时容器...${NC}"
    docker run --rm -it \
        -v maestro-data:/app/ai_researcher/data \
        -v ./maestro_backend/data:/app/data \
        -w /app \
        maestro-backend \
        $CMD
fi

# 清理 - 如果容器正在运行，则从容器中删除脚本
if docker ps --format '{{.Names}}' | grep -q '^maestro-backend$'; then
    docker exec maestro-backend rm -f /app/reset_databases.py 2>/dev/null || true
fi

echo
echo -e "${GREEN}数据库重置操作完成${NC}"

# 如果不只是检查统计信息，提醒重新启动
if [ "$STATS" = false ] && [ "$CHECK" = false ]; then
    echo
    echo -e "${CYAN}下一步:${NC}"
    echo "1. 重启 Docker 容器:"
    echo "   docker compose down"
    echo "   docker compose up -d"
    echo "2. 重新上传您需要的任何文档"
    echo "3. 文档将被处理并在所有数据库中同步"
fi
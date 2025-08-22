#!/bin/bash

# 功能说明: MAESTRO 直接命令行辅助脚本。该脚本提供带实时反馈的文档直接处理功能，绕过后台队列，同步处理文档，并提供实时进度更新。

# MAESTRO 直接命令行辅助脚本
# 该脚本提供带实时反馈的文档直接处理功能

set -e

# 输出颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# 打印带颜色输出的函数
print_info() {
    echo -e "${BLUE}[信息]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[成功]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

print_error() {
    echo -e "${RED}[错误]${NC} $1"
}

# 检查 Docker Compose 是否可用的函数
check_docker_compose() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker 未安装或不在 PATH 中"
        exit 1
    fi
    
    if ! docker compose version &> /dev/null; then
        print_error "Docker Compose 不可用"
        exit 1
    fi
}

# 确保后端正在运行的函数
ensure_backend_running() {
    print_info "正在检查后端是否运行..."
    if ! docker compose ps backend | grep -q "Up"; then
        print_info "正在启动后端服务..."
        docker compose up -d backend
        sleep 5
    fi
}

# 运行直接 CLI 命令的函数
run_direct_cli() {
    check_docker_compose
    ensure_backend_running
    docker compose --profile cli run --rm cli python cli_ingest.py "$@"
}

# 帮助函数
show_help() {
    cat << EOF
MAESTRO 直接命令行辅助脚本

此工具提供带实时反馈的直接文档处理，绕过后台队列。
文档同步处理，并提供实时进度更新。

用法: $0 <命令> [选项]

命令:
  create-user <用户名> <密码> [--full-name "姓名"] [--admin]
    创建一个新的用户账户

  create-group <用户名> <组名> [--description "描述"]
    为用户创建一个文档组

  list-groups [--user <用户名>]
    列出文档组

  ingest <用户名> <文档目录> [--group <组ID>] [--force-reembed] [--device <设备>] [--delete-after-success] [--batch-size <数量>]
    直接处理文档并提供实时反馈 (PDF, Word, Markdown)
    - 支持 PDF, Word (docx, doc) 和 Markdown (md, markdown) 文件
    - 显示每个文档的实时处理进度
    - 同步处理文档 (无后台队列)
    - 处理后文档立即可用
    - 文档添加到用户库 (稍后可整理到组中)
    - 可选：处理成功后删除源文件
    - 使用 --batch-size 控制并行处理 (默认: 5)

  status [--user <用户名>] [--group <组ID>]
    检查文档处理状态

  cleanup [--user <用户名>] [--status <状态>] [--group <组ID>] [--confirm]
    清理具有特定状态（例如，失败、错误文档）的文档
    - 从数据库中删除失败或错误的文档
    - 可选：按用户和/或组筛选
    - 使用 --confirm 跳过确认提示

  cleanup-cli [--dry-run] [--force]
    清理悬挂的 CLI 摄入文档
    - 删除处于“cli_processing”状态的文档（中断的 CLI 摄入）
    - 删除关联的文件和向量存储条目
    - 使用 --dry-run 查看将要删除的内容而不进行更改
    - 使用 --force 跳过确认提示

  search <用户名> <查询> [--limit <数量>]
    搜索特定用户的文档

  reset-db [--backup] [--force] [--stats] [--check]
    重置所有数据库（主数据库、AI 数据库、向量存储）和文档文件
    关键: 所有数据库必须一起重置以保持数据一致性
    - --backup: 重置前创建带时间戳的备份
    - --force: 跳过确认提示 (危险!)
    - --stats: 仅显示数据库统计信息 (不重置)
    - --check: 仅检查数据库之间的数据一致性

  help
    显示此帮助消息

与常规 CLI 的主要区别:
  - 直接处理: 文档立即处理并提供实时反馈
  - 实时进度: 查看处理过程中的每个步骤
  - 无队列: 绕过后台处理器以立即获得结果
  - 实时反馈: 时间戳、进度指示器和详细状态更新

示例:
  # 创建用户和组
  $0 create-user researcher mypass123 --full-name "研究用户"
  $0 create-group researcher "AI 论文" --description "机器学习研究"

  # 直接文档处理，带实时反馈 (无组)
  $0 ingest researcher ./documents

  # 使用特定组处理
  $0 ingest researcher ./documents --group GROUP_ID

  # 使用特定 GPU 设备处理
  $0 ingest researcher ./documents --device cuda:0

  # 强制重新嵌入现有文档
  $0 ingest researcher ./documents --force-reembed

  # 检查状态
  $0 status --user researcher

  # 数据库管理
  $0 reset-db --stats                    # 显示当前数据库统计信息
  $0 reset-db --check                    # 检查数据一致性
  $0 reset-db --backup                   # 重置并备份
  $0 reset-db --force                    # 重置且不确认

有关任何命令的详细帮助:
  $0 <命令> --help

EOF
}

# Main script logic
if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

case "$1" in
    "help"|"--help"|"-h")
        show_help
        ;;
    "create-user")
        shift
        if [ $# -lt 2 ]; then
            print_error "create-user 需要用户名和密码"
            echo "用法: $0 create-user <用户名> <密码> [--full-name \"姓名\"] [--admin]"
            exit 1
        fi
        print_info "Creating user '$1'..."
        run_direct_cli create-user "$@"
        print_success "User creation command completed"
        ;;
    "create-group")
        shift
        if [ $# -lt 2 ]; then
            print_error "create-group 需要用户名和组名"
            echo "用法: $0 create-group <用户名> <组名> [--description \"描述\"]"
            exit 1
        fi
        print_info "Creating group '$2' for user '$1'..."
        run_direct_cli create-group "$@"
        print_success "Group creation command completed"
        ;;
    "list-groups")
        shift
        print_info "Listing document groups..."
        run_direct_cli list-groups "$@"
        ;;
    "ingest")
        shift
        # Check for help flag
        if [[ "$1" == "--help" || "$1" == "-h" ]]; then
            run_direct_cli ingest --help
            exit 0
        fi
        
        if [ $# -lt 2 ]; then
            print_error "ingest 需要用户名和文档目录"
            echo "用法: $0 ingest <用户名> <文档目录> [--group <组ID>] [--force-reembed] [--device <设备>] [--delete-after-success] [--batch-size <数量>]"
            exit 1
        fi
        
        # Check if document directory exists and has supported files
        doc_dir="$2"
        if [ ! -d "$doc_dir" ]; then
            print_error "Document directory '$doc_dir' does not exist"
            exit 1
        fi
        
        # Count supported document types
        pdf_count=$(find "$doc_dir" -name "*.pdf" | wc -l)
        docx_count=$(find "$doc_dir" -name "*.docx" -o -name "*.doc" | wc -l)
        md_count=$(find "$doc_dir" -name "*.md" -o -name "*.markdown" | wc -l)
        total_count=$((pdf_count + docx_count + md_count))
        
        if [ "$total_count" -eq 0 ]; then
            print_warning "No supported document files found in '$doc_dir'"
            print_info "Supported formats: PDF, DOCX, DOC, MD, MARKDOWN"
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 0
            fi
        else
            print_info "Found $total_count supported document files in '$doc_dir':"
            if [ "$pdf_count" -gt 0 ]; then
                print_info "  - $pdf_count PDF files"
            fi
            if [ "$docx_count" -gt 0 ]; then
                print_info "  - $docx_count Word documents"
            fi
            if [ "$md_count" -gt 0 ]; then
                print_info "  - $md_count Markdown files"
            fi
        fi
        
        print_info "Starting DIRECT document processing for user '$1'..."
        print_warning "This will process documents immediately with live feedback"
        
        # Convert local path to container path
        container_path="/app/documents"
        if [[ "$doc_dir" == "./documents" || "$doc_dir" == "documents" ]]; then
            container_path="/app/documents"
        elif [[ "$doc_dir" == "./pdfs" || "$doc_dir" == "pdfs" ]]; then
            # Backwards compatibility - still support ./pdfs
            container_path="/app/pdfs"
        elif [[ "$doc_dir" == /* ]]; then
            print_warning "Using absolute path '$doc_dir' - make sure it's mounted in the container"
            container_path="$doc_dir"
        else
            print_warning "Converting relative path '$doc_dir' to '/app/documents'"
            container_path="/app/documents"
        fi
        
        # Replace the local path with container path for the CLI command
        args=("ingest" "$1" "$container_path")
        shift 2
        args+=("$@")
        
        run_direct_cli "${args[@]}"
        print_success "Direct document processing completed"
        print_info "All documents are now immediately available for search."
        ;;
    "status")
        shift
        print_info "Checking document processing status..."
        run_direct_cli status "$@"
        ;;
    "cleanup")
        shift
        print_info "Starting document cleanup..."
        run_direct_cli cleanup "$@"
        print_success "Cleanup command completed"
        ;;
    "cleanup-cli")
        shift
        print_info "Starting CLI document cleanup..."
        print_warning "This will remove all documents stuck in 'cli_processing' status"
        run_direct_cli cleanup-cli "$@"
        print_success "CLI cleanup completed"
        ;;
    "search")
        shift
        if [ $# -lt 2 ]; then
            print_error "search 需要用户名和查询"
            echo "用法: $0 search <用户名> <查询> [--limit <数量>]"
            exit 1
        fi
        print_info "Searching documents for user '$1'..."
        run_direct_cli search "$@"
        ;;
    "reset-db")
        shift
        
        # Parse reset-db specific arguments
        BACKUP=false
        FORCE=false
        STATS=false
        CHECK=false
        
        for arg in "$@"; do
            case $arg in
                --backup)
                    BACKUP=true
                    ;;
                --force)
                    FORCE=true
                    ;;
                --stats)
                    STATS=true
                    ;;
                --check)
                    CHECK=true
                    ;;
                --help)
                    echo "Database Reset Command"
                    echo "Usage: $0 reset-db [OPTIONS]"
                    echo ""
                    echo "CRITICAL: All databases must be reset together to maintain data consistency!"
                    echo "This includes:"
                    echo "  • Main application database (users, chats, documents)"
                    echo "  • AI researcher database (extracted metadata)"
                    echo "  • ChromaDB vector store (embeddings and chunks)"
                    echo "  • All document files (PDFs, markdown, metadata)"
                    echo ""
                    echo "Options:"
                    echo "  --backup  Create timestamped backups before reset"
                    echo "  --force   Skip confirmation prompts (DANGEROUS!)"
                    echo "  --stats   Show database statistics only (don't reset)"
                    echo "  --check   Check data consistency across databases only"
                    echo "  --help    Show this help message"
                    echo ""
                    echo "Examples:"
                    echo "  $0 reset-db --stats     # Show current statistics"
                    echo "  $0 reset-db --check     # Check data consistency"
                    echo "  $0 reset-db --backup    # Reset with backup"
                    echo "  $0 reset-db --force     # Reset without confirmation"
                    exit 0
                    ;;
                *)
                    print_error "reset-db 的未知选项: $arg"
                    echo "使用 '$0 reset-db --help' 获取用法信息"
                    exit 1
                    ;;
            esac
        done
        
        print_warning "数据库重置操作同时作用于所有数据库!"
        print_info "这确保了所有存储系统之间的数据一致性。"
        
        # 复制重置脚本到容器
        print_info "正在复制重置脚本到 Docker 容器..."
        docker cp reset_databases.py maestro-backend:/app/reset_databases.py 2>/dev/null || {
            print_error "复制重置脚本到容器失败。maestro-backend 是否正在运行？"
            print_info "尝试首先启动后端: docker compose up -d backend"
            exit 1
        }
        
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
        print_info "正在 Docker 容器内部执行数据库操作..."
        
        # 检查容器是否正在运行
        if docker ps --format '{{.Names}}' | grep -q '^maestro-backend$'; then
            # 容器正在运行，使用 exec
            # 使用 -i 进行交互式输入但处理 TTY
            if [ -t 0 ]; then
                docker exec -it maestro-backend $CMD
            else
                docker exec -i maestro-backend $CMD
            fi
        else
            # 容器存在但未运行，使用 run
            print_warning "后端容器未运行。正在启动临时容器..."
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
        
        if [ "$STATS" = false ] && [ "$CHECK" = false ]; then
            print_success "数据库重置成功完成!"
            print_info "建议: 重启 Docker 容器以获得干净状态:"
            print_info "  docker compose down && docker compose up -d"
        fi
        ;;
    *)
        print_error "未知命令: $1"
        echo "使用 '$0 help' 查看可用命令"
        exit 1
        ;;
esac

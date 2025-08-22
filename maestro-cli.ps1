#!/usr/bin/env pwsh

# 功能说明: 适用于 Windows PowerShell 的 MAESTRO 直接命令行辅助脚本。该脚本提供带实时反馈的文档直接处理功能，绕过后台队列，同步处理文档，并提供实时进度更新。

# MAESTRO 直接命令行辅助脚本 (适用于 Windows PowerShell)
# 该脚本提供带实时反馈的直接文档处理

param(
    [Parameter(Position=0)]
    [string]$Command,
    
    [Parameter(Position=1)]
    [string]$Username,
    
    [Parameter(Position=2)]
    [string]$Password,
    
    [Parameter(Position=3)]
    [string]$GroupName,
    
    [Parameter(Position=4)]
    [string]$PdfDirectory,
    
    [Parameter(Position=5)]
    [string]$Query,
    
    [Parameter()]
    [string]$FullName,
    
    [Parameter()]
    [string]$Description,
    
    [Parameter()]
    [string]$Group,
    
    [Parameter()]
    [string]$Status,
    
    [Parameter()]
    [string]$Limit,
    
    [Parameter()]
    [string]$Device,
    
    [Parameter()]
    [int]$BatchSize,
    
    [Parameter()]
    [switch]$Admin,
    
    [Parameter()]
    [switch]$ForceReembed,
    
    [Parameter()]
    [switch]$DeleteAfterSuccess,
    
    [Parameter()]
    [switch]$Confirm,
    
    [Parameter()]
    [switch]$Backup,
    
    [Parameter()]
    [switch]$Force,
    
    [Parameter()]
    [switch]$Stats,
    
    [Parameter()]
    [switch]$Check,
    
    [Parameter()]
    [switch]$Help
)

# 输出颜色定义
$Red = "`e[91m"
$Green = "`e[92m"
$Yellow = "`e[93m"
$Blue = "`e[94m"
$NC = "`e[0m" # 无颜色
 
# 打印带颜色输出的函数
function Write-Info {
    param([string]$Message)
    Write-Host "$Blue[信息]$NC $Message"
}
 
function Write-Success {
    param([string]$Message)
    Write-Host "$Green[成功]$NC $Message"
}
 
function Write-Warning {
    param([string]$Message)
    Write-Host "$Yellow[警告]$NC $Message"
}
 
function Write-Error {
    param([string]$Message)
    Write-Host "$Red[错误]$NC $Message"
}

# 检查 Docker Compose 是否可用的函数
function Test-DockerCompose {
    try {
        $null = docker --version
        $null = docker compose version
        return $true
    }
    catch {
        Write-Error "Docker 或 Docker Compose 未安装或不在 PATH 中"
        return $false
    }
}

# 确保后端正在运行的函数
function Start-BackendIfNeeded {
    Write-Info "正在检查后端是否运行..."
    $composeCmd = Get-ComposeCommand
    $backendStatus = Invoke-Expression "$composeCmd ps backend 2>`$null" | Select-String "Up"
    if (-not $backendStatus) {
        Write-Info "正在启动后端服务..."
        Invoke-Expression "$composeCmd up -d backend"
        Start-Sleep -Seconds 5
    }
}

# 检测要使用哪个 Compose 文件的函数
function Get-ComposeCommand {
    # 检查是否在 Windows 上运行以及 CPU Compose 文件是否存在
    if ((Test-Path "docker-compose.cpu.yml") -and $env:FORCE_CPU_MODE -eq "true") {
        return "docker compose -f docker-compose.cpu.yml"
    }
    # 检查用户是否明确需要 CPU 模式
    elseif ((Test-Path ".env") -and (Get-Content ".env" | Select-String "FORCE_CPU_MODE=true")) {
        if (Test-Path "docker-compose.cpu.yml") {
            return "docker compose -f docker-compose.cpu.yml"
        }
    }
    # 默认为常规 Compose
    return "docker compose"
}

# 运行直接 CLI 命令的函数
function Invoke-DirectCLI {
    param([string[]]$Arguments)
    
    if (-not (Test-DockerCompose)) {
        exit 1
    }
    
    Start-BackendIfNeeded
    $composeCmd = Get-ComposeCommand
    $cmd = "$composeCmd --profile cli run --rm cli python cli_ingest.py"
    Invoke-Expression "$cmd $($Arguments -join ' ')"
}

# 帮助函数
function Show-Help {
    @"
MAESTRO 直接命令行辅助脚本 (适用于 Windows PowerShell)

此工具提供带实时反馈的直接文档处理，绕过后台队列。
文档同步处理，并提供实时进度更新。

用法: .\maestro-cli.ps1 <命令> [选项]

命令:
  create-user <用户名> <密码> [-FullName "姓名"] [-Admin]
    创建一个新的用户账户

  create-group <用户名> <组名> [-Description "描述"]
    为用户创建一个文档组

  list-groups [-Username <用户名>]
    列出文档组

  ingest <用户名> <文档目录> [-Group <组ID>] [-ForceReembed] [-Device <设备>] [-DeleteAfterSuccess] [-BatchSize <数量>]
    直接处理文档并提供实时反馈 (PDF, Word, Markdown)
    - 支持 PDF, Word (docx, doc) 和 Markdown (md, markdown) 文件
    - 显示每个文档的实时处理进度
    - 同步处理文档 (无后台队列)
    - 处理后文档立即可用
    - 文档添加到用户库 (稍后可整理到组中)
    - 可选：处理成功后删除源文件
    - 使用 -BatchSize 控制并行处理 (默认: 5)

  status [-Username <用户名>] [-Group <组ID>]
    检查文档处理状态

  cleanup [-Username <用户名>] [-Status <状态>] [-Group <组ID>] [-Confirm]
    清理具有特定状态（例如，失败、错误文档）的文档
    - 从数据库中删除失败或错误的文档
    - 可选：按用户和/或组筛选
    - 使用 -Confirm 跳过确认提示

  search <用户名> <查询> [-Limit <数量>]
    搜索特定用户的文档

  reset-db [-Backup] [-Force] [-Stats] [-Check]
    重置所有数据库（主数据库、AI 数据库、向量存储）和文档文件
    关键: 所有数据库必须一起重置以保持数据一致性
    - -Backup: 重置前创建带时间戳的备份
    - -Force: 跳过确认提示 (危险!)
    - -Stats: 仅显示数据库统计信息 (不重置)
    - -Check: 仅检查数据库之间的数据一致性

  help
    显示此帮助消息

与常规 CLI 的主要区别:
  - 直接处理: 文档立即处理并提供实时反馈
  - 实时进度: 查看处理过程中的每个步骤
  - 无队列: 绕过后台处理器以立即获得结果
  - 实时反馈: 时间戳、进度指示器和详细状态更新

示例:
  # 创建用户和组
  .\maestro-cli.ps1 create-user researcher mypass123 -FullName "研究用户"
  .\maestro-cli.ps1 create-group researcher "AI 论文" -Description "机器学习研究"

  # 直接文档处理，带实时反馈 (无组)
  .\maestro-cli.ps1 ingest researcher ./documents

  # 使用特定组处理
  .\maestro-cli.ps1 ingest researcher ./documents -Group GROUP_ID

  # 使用特定 GPU 设备处理
  .\maestro-cli.ps1 ingest researcher ./documents -Device cuda:0

  # 强制重新嵌入现有文档
  .\maestro-cli.ps1 ingest researcher ./documents -ForceReembed

  # 检查状态
  .\maestro-cli.ps1 status -Username researcher

有关任何命令的详细帮助:
  .\maestro-cli.ps1 <命令> -Help
"@
}

# Main script logic
if (-not $Command -or $Help) {
    Show-Help
    exit 0
}

switch ($Command.ToLower()) {
    "create-user" {
        if (-not $Username -or -not $Password) {
            Write-Error "create-user 需要用户名和密码"
            Write-Host "用法: .\maestro-cli.ps1 create-user <用户名> <密码> [-FullName `"姓名`"] [-Admin]"
            exit 1
        }
        
        Write-Info "正在创建用户 '$Username'..."
        $args = @("create-user", $Username, $Password)
        if ($FullName) { $args += "--full-name", $FullName }
        if ($Admin) { $args += "--admin" }
        
        Invoke-DirectCLI $args
        Write-Success "用户创建命令完成"
    }
    
    "create-group" {
        if (-not $Username -or -not $GroupName) {
            Write-Error "create-group 需要用户名和组名"
            Write-Host "用法: .\maestro-cli.ps1 create-group <用户名> <组名> [-Description `"描述`"]"
            exit 1
        }
        
        Write-Info "正在为用户 '$Username' 创建组 '$GroupName'..."
        $args = @("create-group", $Username, $GroupName)
        if ($Description) { $args += "--description", $Description }
        
        Invoke-DirectCLI $args
        Write-Success "组创建命令完成"
    }
    
    "list-groups" {
        Write-Info "正在列出文档组..."
        $args = @("list-groups")
        if ($Username) { $args += "--user", $Username }
        
        Invoke-DirectCLI $args
    }
    
    "ingest" {
        if (-not $Username -or -not $PdfDirectory) {
            Write-Error "ingest 需要用户名和文档目录"
            Write-Host "用法: .\maestro-cli.ps1 ingest <用户名> <文档目录> [-Group <组ID>] [-ForceReembed] [-Device <设备>] [-DeleteAfterSuccess] [-BatchSize <数量>]"
            exit 1
        }
        
        # 检查文档目录是否存在
        if (-not (Test-Path $PdfDirectory)) {
            Write-Error "文档目录 '$PdfDirectory' 不存在"
            exit 1
        }
        
        # 计算支持的文档类型数量
        $pdfFiles = Get-ChildItem -Path $PdfDirectory -Filter "*.pdf" -ErrorAction SilentlyContinue
        $docxFiles = Get-ChildItem -Path $PdfDirectory -Include "*.docx", "*.doc" -Recurse -ErrorAction SilentlyContinue
        $mdFiles = Get-ChildItem -Path $PdfDirectory -Include "*.md", "*.markdown" -Recurse -ErrorAction SilentlyContinue
        $totalFiles = $pdfFiles.Count + $docxFiles.Count + $mdFiles.Count
        
        if ($totalFiles -eq 0) {
            Write-Warning "在 '$PdfDirectory' 中未找到支持的文档文件"
            Write-Info "支持的格式: PDF, DOCX, DOC, MD, MARKDOWN"
            $continue = Read-Host "是否继续？(y/N)"
            if ($continue -ne "y" -and $continue -ne "Y") {
                exit 0
            }
        } else {
            Write-Info "在 '$PdfDirectory' 中找到 $totalFiles 个支持的文档文件:"
            if ($pdfFiles.Count -gt 0) {
                Write-Info "  - $($pdfFiles.Count) 个 PDF 文件"
            }
            if ($docxFiles.Count -gt 0) {
                Write-Info "  - $($docxFiles.Count) 个 Word 文档"
            }
            if ($mdFiles.Count -gt 0) {
                Write-Info "  - $($mdFiles.Count) 个 Markdown 文件"
            }
        }
        
        Write-Info "正在为用户 '$Username' 启动直接文档处理..."
        Write-Warning "这将立即处理文档并提供实时反馈"
        
        # 将本地路径转换为容器路径
        $containerPath = "/app/documents"
        if ($PdfDirectory -eq "./documents" -or $PdfDirectory -eq "documents") {
            $containerPath = "/app/documents"
        } elseif ($PdfDirectory -eq "./pdfs" -or $PdfDirectory -eq "pdfs") {
            # 向后兼容 - 仍然支持 ./pdfs
            $containerPath = "/app/pdfs"
        } elseif ($PdfDirectory.StartsWith("\") -or $PdfDirectory.StartsWith("/")) {
            Write-Warning "使用绝对路径 '$PdfDirectory' - 确保已挂载到容器中"
            $containerPath = $PdfDirectory
        } else {
            Write-Warning "正在将相对路径 '$PdfDirectory' 转换为 '/app/documents'"
            $containerPath = "/app/documents"
        }
        
        # 构建参数
        $args = @("ingest", $Username, $containerPath)
        if ($Group) { $args += "--group", $Group }
        if ($ForceReembed) { $args += "--force-reembed" }
        if ($Device) { $args += "--device", $Device }
        if ($DeleteAfterSuccess) { $args += "--delete-after-success" }
        if ($BatchSize) { $args += "--batch-size", $BatchSize }
        
        Invoke-DirectCLI $args
        Write-Success "直接文档处理完成"
        Write-Info "所有文档现在立即可用于搜索。"
    }
    
    "status" {
        Write-Info "正在检查文档处理状态..."
        $args = @("status")
        if ($Username) { $args += "--user", $Username }
        if ($Group) { $args += "--group", $Group }
        
        Invoke-DirectCLI $args
    }
    
    "cleanup" {
        Write-Info "正在启动文档清理..."
        $args = @("cleanup")
        if ($Username) { $args += "--user", $Username }
        if ($Status) { $args += "--status", $Status }
        if ($Group) { $args += "--group", $Group }
        if ($Confirm) { $args += "--confirm" }
        
        Invoke-DirectCLI $args
        Write-Success "清理命令完成"
    }
    
    "search" {
        if (-not $Username -or -not $Query) {
            Write-Error "search 需要用户名和查询"
            Write-Host "用法: .\maestro-cli.ps1 search <用户名> <查询> [-Limit <数量>]"
            exit 1
        }
        
        Write-Info "正在为用户 '$Username' 搜索文档..."
        $args = @("search", $Username, $Query)
        if ($Limit) { $args += "--limit", $Limit }
        
        Invoke-DirectCLI $args
    }
    
    "reset-db" {
        Write-Warning "数据库重置操作同时作用于所有数据库!"
        Write-Info "这确保了所有存储系统之间的数据一致性。"
        
        # 复制重置脚本到容器
        Write-Info "正在复制重置脚本到 Docker 容器..."
        $copyResult = docker cp reset_databases.py maestro-backend:/app/reset_databases.py 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "复制重置脚本到容器失败。maestro-backend 是否正在运行？"
            Write-Info "尝试首先启动后端: docker compose up -d backend"
            exit 1
        }
        
        # 构建命令
        $cmd = "python /app/reset_databases.py"
        if ($Backup) { $cmd += " --backup" }
        if ($Force) { $cmd += " --force" }
        if ($Stats) { $cmd += " --stats" }
        if ($Check) { $cmd += " --check" }
        
        # 在容器内部执行重置脚本
        Write-Info "正在 Docker 容器内部执行数据库操作..."
        
        # 检查容器是否正在运行
        $containerRunning = docker ps --format '{{.Names}}' | Select-String "maestro-backend"
        if ($containerRunning) {
            # 容器正在运行，使用 exec
            docker exec -it maestro-backend $cmd
        } else {
            # 容器存在但未运行，使用 run
            Write-Warning "后端容器未运行。正在启动临时容器..."
            $composeCmd = Get-ComposeCommand
            docker run --rm -it `
                -v maestro-data:/app/ai_researcher/data `
                -v "./maestro_backend/data:/app/data" `
                -w /app `
                maestro-backend `
                $cmd
        }
        
        # 清理 - 如果容器正在运行，则从容器中删除脚本
        if ($containerRunning) {
            docker exec maestro-backend rm -f /app/reset_databases.py 2>$null
        }
        
        if (-not $Stats -and -not $Check) {
            Write-Success "数据库重置成功完成!"
            Write-Info "建议: 重启 Docker 容器以获得干净状态:"
            Write-Info "  docker compose down && docker compose up -d"
        }
    }
    
    default {
        Write-Error "未知命令: $Command"
        Write-Host "使用 '.\maestro-cli.ps1 help' 查看可用命令"
        exit 1
    }
}
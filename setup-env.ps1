#!/usr/bin/env pwsh

# 功能说明: 适用于 Windows PowerShell 的 MAESTRO 环境设置脚本。该脚本帮助您首次设置 `.env` 文件，引导完成基本配置。

# MAESTRO - 适用于 Windows PowerShell 的环境设置脚本
# 该脚本帮助您首次设置 .env 文件

Write-Host "# MAESTRO - 环境设置"
Write-Host "=================================="

# 检查 .env 是否已存在
if (Test-Path ".env") {
    Write-Host "警告: .env 文件已存在!" -ForegroundColor Yellow
    $overwrite = Read-Host "您要覆盖它吗？(y/N)"
    if ($overwrite -ne "y" -and $overwrite -ne "Y") {
        Write-Host "设置已取消。"
        exit 0
    }
}

# 复制 .env.example 到 .env
if (-not (Test-Path ".env.example")) {
    Write-Host "错误: 未找到 .env.example 文件!" -ForegroundColor Red
    Write-Host "请确保您在正确的目录下。"
    exit 1
}

Copy-Item ".env.example" ".env"
Write-Host "成功: 已从 .env.example 创建 .env" -ForegroundColor Green

# 简化配置
Write-Host ""
Write-Host "MAESTRO 配置" -ForegroundColor Cyan
Write-Host ""

# 设置模式选择
Write-Host "选择设置模式:"
Write-Host "1) 简单 (仅限 localhost) - 推荐"
Write-Host "2) 网络 (从其他设备访问)"
Write-Host "3) 自定义域 (用于反向代理)"
$setupMode = Read-Host "选择 (1-3, 默认为 1)"
if (-not $setupMode) { $setupMode = "1" }

switch ($setupMode) {
    "2" {
        # 网络设置 - 尝试检测 IP
        $ip = (Get-NetIPAddress | Where-Object {$_.AddressFamily -eq "IPv4" -and $_.InterfaceAlias -notlike "*Loopback*" -and $_.IPAddress -notlike "169.254.*"}).IPAddress | Select-Object -First 1
        
        if ($ip) {
            Write-Host "自动检测到 IP: $ip"
            $useDetected = Read-Host "使用此 IP 吗？(Y/n)"
            if ($useDetected -eq "n" -or $useDetected -eq "N") {
                $ip = Read-Host "输入 IP 地址"
            }
        } else {
            $ip = Read-Host "输入 IP 地址"
        }
        
        (Get-Content .env) -replace 'CORS_ALLOWED_ORIGINS=\*', "CORS_ALLOWED_ORIGINS=http://$ip,http://localhost" | Set-Content .env
        Write-Host "成功: 已配置网络访问: $ip" -ForegroundColor Green
    }
    "3" {
        $domain = Read-Host "输入您的域名 (例如, researcher.local)"
        $useHttps = Read-Host "使用 HTTPS 吗？(y/N)"
        
        if ($useHttps -eq "y" -or $useHttps -eq "Y") {
            $protocol = "https"
        } else {
            $protocol = "http"
        }
        
        (Get-Content .env) -replace 'CORS_ALLOWED_ORIGINS=\*', "CORS_ALLOWED_ORIGINS=$protocol`://$domain" | Set-Content .env
        (Get-Content .env) -replace 'ALLOW_CORS_WILDCARD=true', 'ALLOW_CORS_WILDCARD=false' | Set-Content .env
        Write-Host "成功: 已配置自定义域名: $protocol`://$domain" -ForegroundColor Green
    }
    default {
        Write-Host "成功: 正在使用简单的 localhost 配置" -ForegroundColor Green
        Write-Host "   应用程序将可在以下地址访问: http://localhost"
    }
}

# 端口配置
Write-Host ""
$maestroPort = Read-Host "MAESTRO 端口 (默认: 80)"
if (-not $maestroPort) { $maestroPort = "80" }
(Get-Content .env) -replace 'MAESTRO_PORT=80', "MAESTRO_PORT=$maestroPort" | Set-Content .env

# 数据库安全配置
Write-Host ""
Write-Host "数据库安全设置" -ForegroundColor Cyan
Write-Host "选择设置数据库密码的方式:"
Write-Host "1) 生成安全的随机密码 (推荐)"
Write-Host "2) 输入自定义密码"
Write-Host "3) 跳过 (使用默认值 - 不推荐用于生产环境)"
$passMode = Read-Host "选择 (1-3, 默认: 1)"
if (-not $passMode) { $passMode = "1" }

switch ($passMode) {
    "1" {
        # 生成安全的随机密码
        $postgresPass = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 25 | ForEach-Object {[char]$_})
        $adminPass = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 16 | ForEach-Object {[char]$_})
        $jwtSecret = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 64 | ForEach-Object {[char]$_})
        
        (Get-Content .env) -replace 'POSTGRES_PASSWORD=CHANGE_THIS_PASSWORD_IMMEDIATELY', "POSTGRES_PASSWORD=$postgresPass" | Set-Content .env
        (Get-Content .env) -replace 'ADMIN_PASSWORD=CHANGE_THIS_ADMIN_PASSWORD', "ADMIN_PASSWORD=$adminPass" | Set-Content .env
        (Get-Content .env) -replace 'JWT_SECRET_KEY=GENERATE_A_RANDOM_KEY_DO_NOT_USE_DEFAULT', "JWT_SECRET_KEY=$jwtSecret" | Set-Content .env
        
        Write-Host "成功: 已生成安全密码" -ForegroundColor Green
        Write-Host ""
        Write-Host "保存这些凭据:" -ForegroundColor Yellow
        Write-Host "   管理员用户名: admin" -ForegroundColor Yellow
        Write-Host "   管理员密码: $adminPass" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "   数据库凭据存储在 .env 中" -ForegroundColor Gray
    }
    "2" {
        # 自定义密码
        $postgresPass = Read-Host "输入 PostgreSQL 密码" -AsSecureString
        $postgresPassConfirm = Read-Host "确认 PostgreSQL 密码" -AsSecureString
        
        # 将 SecureString 转换为纯文本进行比较
        $postgresPassPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($postgresPass))
        $postgresPassConfirmPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($postgresPassConfirm))
        
        if ($postgresPassPlain -ne $postgresPassConfirmPlain) {
            Write-Host "错误: 密码不匹配。正在使用默认值。" -ForegroundColor Red
        } else {
            $adminPass = Read-Host "输入管理员密码" -AsSecureString
            $adminPassPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($adminPass))
            
            $jwtSecret = Read-Host "输入 JWT 密钥 (按 Enter 生成)"
            if (-not $jwtSecret) {
                $jwtSecret = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 64 | ForEach-Object {[char]$_})
                Write-Host "已生成 JWT 密钥" -ForegroundColor Green
            }
            
            (Get-Content .env) -replace 'POSTGRES_PASSWORD=CHANGE_THIS_PASSWORD_IMMEDIATELY', "POSTGRES_PASSWORD=$postgresPassPlain" | Set-Content .env
            (Get-Content .env) -replace 'ADMIN_PASSWORD=CHANGE_THIS_ADMIN_PASSWORD', "ADMIN_PASSWORD=$adminPassPlain" | Set-Content .env
            (Get-Content .env) -replace 'JWT_SECRET_KEY=GENERATE_A_RANDOM_KEY_DO_NOT_USE_DEFAULT', "JWT_SECRET_KEY=$jwtSecret" | Set-Content .env
            
            Write-Host "成功: 已设置自定义密码" -ForegroundColor Green
            Write-Host ""
            Write-Host "   管理员用户名: admin" -ForegroundColor Yellow
            Write-Host "   管理员密码: [您的自定义密码]" -ForegroundColor Yellow
        }
    }
    "3" {
        Write-Host "警告: 正在使用默认密码 - 在生产环境中请务必更改!" -ForegroundColor Yellow
        Write-Host "   默认管理员登录: admin / admin123" -ForegroundColor Yellow
    }
    default {
        Write-Host "无效选择。正在使用默认值。" -ForegroundColor Red
    }
}

# 时区
Write-Host ""
Write-Host "选择您的时区:"
Write-Host "1) America/New_York (东部时间)"
Write-Host "2) America/Chicago (中部时间)"
Write-Host "3) America/Denver (山区时间)"
Write-Host "4) America/Los_Angeles (太平洋时间)"
Write-Host "5) Asia/Kolkata (印度标准时间)"
Write-Host "6) Europe/London (格林威治时间/英国夏令时)"
Write-Host "7) Europe/Paris (中欧时间/中欧夏令时)"
Write-Host "8) Asia/Tokyo (日本标准时间)"
Write-Host "9) Australia/Sydney (澳大利亚东部标准时间/澳大利亚东部夏令时)"
Write-Host "10) 其他 (输入自定义时区)"
Write-Host "0) 使用系统默认"

$timezoneChoice = Read-Host "选择 (0-10, 默认: 2)"

switch ($timezoneChoice) {
    "1" { $timezone = "America/New_York" }
    "2" { $timezone = "America/Chicago" }
    "3" { $timezone = "America/Denver" }
    "4" { $timezone = "America/Los_Angeles" }
    "5" { $timezone = "Asia/Kolkata" }
    "6" { $timezone = "Europe/London" }
    "7" { $timezone = "Europe/Paris" }
    "8" { $timezone = "Asia/Tokyo" }
    "9" { $timezone = "Australia/Sydney" }
    "10" {
        Write-Host ""
        Write-Host "常见的时区格式:"
        Write-Host "  - America/New_York"
        Write-Host "  - Asia/Kolkata"
        Write-Host "  - Europe/London"
        Write-Host "  - Asia/Tokyo"
        Write-Host "  - UTC"
        Write-Host "  - GMT"
        $timezone = Read-Host "输入您的时区"
        if (-not $timezone) { $timezone = "America/Chicago" }
    }
    "0" {
        # 尝试获取系统时区
        try {
            $systemTz = [System.TimeZoneInfo]::Local.Id
            $timezone = $systemTz
            Write-Host "成功: 正在使用系统时区: $timezone" -ForegroundColor Green
        } catch {
            $timezone = "America/Chicago"
            Write-Host "警告: 无法检测到系统时区，正在使用默认值: $timezone" -ForegroundColor Yellow
        }
    }
    default { $timezone = "America/Chicago" }
}

(Get-Content .env) -replace 'TZ=America/Chicago', "TZ=$timezone" | Set-Content .env
(Get-Content .env) -replace 'VITE_SERVER_TIMEZONE=America/Chicago', "VITE_SERVER_TIMEZONE=$timezone" | Set-Content .env

Write-Host ""
Write-Host "设置完成!" -ForegroundColor Green
Write-Host ""
Write-Host "您的 .env 文件已创建。"
Write-Host ""

# Windows 行尾警告
Write-Host "警告 - Windows/WSL 注意事项:" -ForegroundColor Yellow
Write-Host "   如果您遇到 'bad interpreter' 错误，请运行:" -ForegroundColor Yellow
Write-Host "   docker compose down" -ForegroundColor Cyan
Write-Host "   docker compose build --no-cache" -ForegroundColor Cyan
Write-Host "   docker compose up -d" -ForegroundColor Cyan
Write-Host ""

Write-Host "访问 MAESTRO 地址:"
if ($maestroPort -eq "80") {
    switch ($setupMode) {
        "2" { Write-Host "  http://$ip" }
        "3" { Write-Host "  $protocol`://$domain" }
        default { Write-Host "  http://localhost" }
    }
} else {
    switch ($setupMode) {
        "2" { Write-Host "  http://$ip`:$maestroPort" }
        "3" { Write-Host "  $protocol`://$domain`:$maestroPort" }
        default { Write-Host "  http://localhost:$maestroPort" }
    }
}
Write-Host ""
if ($passMode -eq "3") {
    Write-Host "默认登录信息:" -ForegroundColor Cyan
    Write-Host "  用户名: admin"
    Write-Host "  密码: admin123"
} else {
    Write-Host "登录凭据已显示在上方" -ForegroundColor Cyan
}
Write-Host ""
Write-Host "使用以下命令启动 MAESTRO:"
Write-Host "  docker compose up -d" -ForegroundColor Cyan
Write-Host ""
Write-Host "重要 - 首次运行:" -ForegroundColor Yellow
Write-Host "  首次启动需要 5-10 分钟下载 AI 模型" -ForegroundColor Yellow
Write-Host "  通过以下命令监控进度: docker compose logs -f maestro-backend" -ForegroundColor Yellow
Write-Host "  等待消息: Application startup complete" -ForegroundColor Yellow
Write-Host ""
Write-Host "稍后修改设置:"
Write-Host "  notepad .env"
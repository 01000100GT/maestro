#!/usr/bin/env pwsh

# 功能说明: 该脚本用于修复 Windows/WSL 用户的文件行尾符问题，确保脚本在不同操作系统上的兼容性。

# 修复 Windows/WSL 用户的行尾符
Write-Host "正在修复 Windows/WSL 兼容性的行尾符..." -ForegroundColor Yellow

# 检查 Git Bash 是否可用
$gitBashPath = @(
    "C:\Program Files\Git\bin\bash.exe",
    "C:\Program Files (x86)\Git\bin\bash.exe",
    "$env:PROGRAMFILES\Git\bin\bash.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($gitBashPath) {
    Write-Host "正在使用 Git Bash 修复行尾符..." -ForegroundColor Green
    & $gitBashPath -c "find . -type f \( -name '*.sh' -o -name '*.py' -o -name 'Dockerfile*' \) -exec sed -i 's/\r$//' {} \;"
    Write-Host "✅ 行尾符已修复!" -ForegroundColor Green
} else {
    # 备用方案: 使用 PowerShell 修复行尾符
    Write-Host "未找到 Git Bash。正在使用 PowerShell 修复行尾符..." -ForegroundColor Yellow
    
    $files = Get-ChildItem -Recurse -Include "*.sh","*.py","Dockerfile*" -File
    
    foreach ($file in $files) {
        $content = Get-Content $file.FullName -Raw
        if ($content -match "`r`n") {
            $content = $content -replace "`r`n", "`n"
            [System.IO.File]::WriteAllText($file.FullName, $content, [System.Text.UTF8Encoding]::new($false))
            Write-Host "  已修复: $($file.Name)"
        }
    }
    Write-Host "✅ 行尾符已修复!" -ForegroundColor Green
}

Write-Host ""
Write-Host "现在重建并重启 Docker:" -ForegroundColor Cyan
Write-Host "  docker compose down" -ForegroundColor White
Write-Host "  docker compose build --no-cache maestro-backend" -ForegroundColor White
Write-Host "  docker compose up -d" -ForegroundColor White
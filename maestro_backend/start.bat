@echo off
REM 功能说明: MAESTRO 后端启动批处理脚本（适用于 Windows）。此脚本在 Windows 环境下为 MAESTRO 后端运行数据库迁移，然后启动 FastAPI 服务器。

REM 适用于 Windows 的 MAESTRO 后端启动脚本
REM 该脚本在启动 FastAPI 服务器之前运行数据库迁移

echo 🚀 正在启动 MAESTRO 后端...

REM 运行数据库迁移
echo 📊 正在运行数据库迁移...
python -m database.run_migrations

REM 检查迁移是否成功
if errorlevel 1 (
    echo ❌ 数据库迁移失败!
    exit /b 1
) else (
    echo ✅ 数据库迁移成功完成!
)

REM 启动 FastAPI 服务器
echo 🌐 正在启动 FastAPI 服务器...
REM 将 LOG_LEVEL 转换为小写以用于 uvicorn
for /f "tokens=*" %%i in ('echo %LOG_LEVEL% ^| powershell -Command "$input = Read-Host; $input.ToLower()"') do set UVICORN_LOG_LEVEL=%%i
if "%UVICORN_LOG_LEVEL%"=="" set UVICORN_LOG_LEVEL=error

uvicorn main:app --host 0.0.0.0 --port 8000 --reload --log-level %UVICORN_LOG_LEVEL%
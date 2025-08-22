#!/bin/bash

# 功能说明: MAESTRO 环境设置脚本。该脚本帮助您首次设置 `.env` 文件，引导完成基本配置。

# MAESTRO - 环境设置脚本
# 该脚本帮助您首次设置 .env 文件

set -e

echo "# MAESTRO - 环境设置"
echo "=================================="

# 检查 .env 是否已存在
if [ -f ".env" ]; then
    echo "⚠️  .env 文件已存在!"
    read -p "您要覆盖它吗？(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "设置已取消。"
        exit 0
    fi
fi

# 复制 .env.example 到 .env
if [ ! -f ".env.example" ]; then
    echo "❌ 未找到 .env.example 文件!"
    echo "请确保您在正确的目录下。"
    exit 1
fi

cp .env.example .env
echo "✅ 已从 .env.example 创建 .env"

# 提示进行基本配置
echo ""
echo "📝 基本配置设置"
echo "您可以稍后在 .env 文件中修改这些值"
echo ""

# 检测操作系统以兼容 sed
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS 需要备份扩展才能进行原地编辑
    SED_INPLACE=(-i '')
else
    # Linux 不需要备份扩展
    SED_INPLACE=(-i)
fi

# 简单设置模式
echo ""
echo "选择设置模式:"
echo "1) 简单 (仅限 localhost) - 推荐给大多数用户"
echo "2) 网络 (从其他设备访问)"
echo "3) 自定义域 (用于反向代理设置)"
read -p "选择 (1-3, 默认: 1): " setup_mode
setup_mode=${setup_mode:-1}

case $setup_mode in
    2)
        # 自动检测网络访问的机器 IP
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS 特定的 IP 检测
            ip=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -1)
        else
            # Linux IP 检测
            ip=$(hostname -I 2>/dev/null | awk '{print $1}')
        fi
        
        if [ -n "$ip" ]; then
            echo "🔍 自动检测到 IP: $ip"
            read -p "使用此 IP 吗？(Y/n): " use_detected
            if [[ $use_detected =~ ^[Nn]$ ]]; then
                read -p "输入 IP 地址: " ip
            fi
        else
            read -p "输入 IP 地址: " ip
        fi
        
        # 将 IP 添加到 CORS 允许的来源
        sed "${SED_INPLACE[@]}" "s/CORS_ALLOWED_ORIGINS=\*/CORS_ALLOWED_ORIGINS=http:\/\/$ip,http:\/\/localhost/" .env
        echo "✅ 已配置网络访问: $ip"
        ;;
    3)
        read -p "输入您的域名 (例如, researcher.local 或 app.example.com): " domain
        read -p "使用 HTTPS 吗？(y/N): " use_https
        
        if [[ $use_https =~ ^[Yy]$ ]]; then
            protocol="https"
        else
            protocol="http"
        fi
        
        # 为自定义域设置 CORS
        sed "${SED_INPLACE[@]}" "s/CORS_ALLOWED_ORIGINS=\*/CORS_ALLOWED_ORIGINS=$protocol:\/\/$domain/" .env
        sed "${SED_INPLACE[@]}" "s/ALLOW_CORS_WILDCARD=true/ALLOW_CORS_WILDCARD=false/" .env
        echo "✅ 已配置自定义域: $protocol://$domain"
        ;;
    *)
        # 简单的 localhost 设置 - 无需更改
        echo "✅ 正在使用简单的 localhost 配置"
        echo "   应用程序将可在以下地址访问: http://localhost"
        ;;
esac

# 端口配置
echo ""
read -p "MAESTRO 端口 (默认: 80): " maestro_port
maestro_port=${maestro_port:-80}
sed "${SED_INPLACE[@]}" "s/MAESTRO_PORT=80/MAESTRO_PORT=$maestro_port/" .env

# 数据库安全配置
echo ""
echo "🔐 数据库安全设置"
echo "选择设置数据库密码的方式:"
echo "1) 生成安全的随机密码 (推荐)"
echo "2) 输入自定义密码"
echo "3) 跳过 (使用默认值 - 不推荐用于生产环境)"
read -p "选择 (1-3, 默认: 1): " pass_mode
pass_mode=${pass_mode:-1}

case $pass_mode in
    1)
        # 生成安全的随机密码
        if command -v openssl &> /dev/null; then
            postgres_pass=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
            admin_pass=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)
            jwt_secret=$(openssl rand -hex 32)
        else
            # 如果 openssl 不可用，则回退到 /dev/urandom
            postgres_pass=$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 25)
            admin_pass=$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16)
            jwt_secret=$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 64)
        fi
        
        sed "${SED_INPLACE[@]}" "s/POSTGRES_PASSWORD=CHANGE_THIS_PASSWORD_IMMEDIATELY/POSTGRES_PASSWORD=$postgres_pass/" .env
        sed "${SED_INPLACE[@]}" "s/ADMIN_PASSWORD=CHANGE_THIS_ADMIN_PASSWORD/ADMIN_PASSWORD=$admin_pass/" .env
        sed "${SED_INPLACE[@]}" "s/JWT_SECRET_KEY=GENERATE_A_RANDOM_KEY_DO_NOT_USE_DEFAULT/JWT_SECRET_KEY=$jwt_secret/" .env
        
        echo "✅ 已生成安全密码"
        echo ""
        echo "⚠️  保存这些凭据:"
        echo "   管理员用户名: admin"
        echo "   管理员密码: $admin_pass"
        echo ""
        echo "   数据库凭据存储在 .env 中"
        ;;
    2)
        # 自定义密码
        read -sp "输入 PostgreSQL 密码: " postgres_pass
        echo
        read -sp "确认 PostgreSQL 密码: " postgres_pass_confirm
        echo
        if [ "$postgres_pass" != "$postgres_pass_confirm" ]; then
            echo "❌ 密码不匹配。正在使用默认值。"
        else
            sed "${SED_INPLACE[@]}" "s/POSTGRES_PASSWORD=CHANGE_THIS_PASSWORD_IMMEDIATELY/POSTGRES_PASSWORD=$postgres_pass/" .env
        fi
        
        read -sp "输入管理员密码: " admin_pass
        echo
        read -sp "确认管理员密码: " admin_pass_confirm
        echo
        if [ "$admin_pass" != "$admin_pass_confirm" ]; then
            echo "❌ 密码不匹配。正在使用默认值。"
        else
            sed "${SED_INPLACE[@]}" "s/ADMIN_PASSWORD=CHANGE_THIS_ADMIN_PASSWORD/ADMIN_PASSWORD=$admin_pass/" .env
        fi
        
        # 生成 JWT 密钥
        if command -v openssl &> /dev/null; then
            jwt_secret=$(openssl rand -hex 32)
        else
            jwt_secret=$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 64)
        fi
        sed "${SED_INPLACE[@]}" "s/JWT_SECRET_KEY=GENERATE_A_RANDOM_KEY_DO_NOT_USE_DEFAULT/JWT_SECRET_KEY=$jwt_secret/" .env
        
        echo "✅ 已设置自定义密码"
        ;;
    *)
        echo "⚠️  警告: 使用默认密码不安全!"
        echo "   请在部署到生产环境之前在 .env 中更改它们"
        admin_pass="admin123"  # 用于稍后显示
        ;;
esac

# 时区
read -p "时区 (默认: America/Chicago): " timezone
timezone=${timezone:-America/Chicago}
sed "${SED_INPLACE[@]}" "s|TZ=America/Chicago|TZ=$timezone|" .env
sed "${SED_INPLACE[@]}" "s|VITE_SERVER_TIMEZONE=America/Chicago|VITE_SERVER_TIMEZONE=$timezone|" .env

echo ""
echo "🎉 设置完成!"
echo ""
echo "您的 .env 文件已创建。"
echo ""
echo "访问 MAESTRO 地址:"
if [ "$maestro_port" = "80" ]; then
    case $setup_mode in
        2) echo "  http://$ip" ;;
        3) echo "  $protocol://$domain" ;;
        *) echo "  http://localhost" ;;
    esac
else
    case $setup_mode in
        2) echo "  http://$ip:$maestro_port" ;;
        3) echo "  $protocol://$domain:$maestro_port" ;;
        *) echo "  http://localhost:$maestro_port" ;;
    esac
fi
echo ""
if [ "$pass_mode" != "3" ]; then
    echo "登录凭据:"
    echo "  用户名: admin"
    if [ -n "$admin_pass" ]; then
        echo "  密码: [在设置过程中设置 - 请查看上方或 .env 文件]"
    fi
else
    echo "默认登录信息 (请立即更改):"
    echo "  用户名: admin"
    echo "  密码: admin123"
fi
echo ""
echo "使用以下命令启动 MAESTRO:"
echo "  docker compose up -d"
echo ""
echo "⚠️  重要 - 首次运行:"
echo "  首次启动需要 5-10 分钟下载 AI 模型"
echo "  通过以下命令监控进度: docker compose logs -f maestro-backend"
echo "  等待消息: Application startup complete"
echo ""
echo "稍后修改设置:"
echo "  nano .env"

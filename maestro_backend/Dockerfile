# 功能说明: MAESTRO 后端 Docker 镜像构建文件。此文件定义了如何构建 MAESTRO 后端的 Docker 镜像，包括安装系统依赖、Python 库、复制应用程序代码，并进行启动脚本设置。

# 使用 NVIDIA CUDA 基础镜像以支持 GPU (已验证可用版本)
FROM nvidia/cuda:12.4.0-runtime-ubuntu22.04

WORKDIR /app

# 安装系统依赖和 Python
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    python3.10 \
    python3.10-dev \
    python3-pip \
    python3-setuptools \
    python3-wheel \
    # WeasyPrint 依赖
    libpango-1.0-0 \
    libpangoft2-1.0-0 \
    libharfbuzz0b \
    libffi-dev \
    libjpeg-dev \
    libopenjp2-7-dev \
    libcairo2 \
    libgdk-pixbuf2.0-0 \
    libfribidi0 \
    libglib2.0-0 \
    libpangocairo-1.0-0 \
    libpango1.0-dev \
    libcairo2-dev \
    pandoc \
    dos2unix \
    && rm -rf /var/lib/apt/lists/*

# 使用 Python 3.10 作为默认
RUN ln -sf /usr/bin/python3.10 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip

# 首先复制 requirements 以获得更好的缓存效果
COPY requirements.txt /app/requirements.txt

# 安装 Python 依赖
RUN pip install --no-cache-dir -r requirements.txt

# 复制应用程序代码
COPY . /app/

# 修复 shell 脚本的行尾 (适用于 Windows 用户)
RUN find /app -type f -name "*.sh" -exec dos2unix {} \;

# 使启动脚本可执行
RUN chmod +x /app/start.sh

# 设置环境变量
ENV PYTHONPATH=/app

# 暴露 FastAPI 的端口
EXPOSE 8000

# 使用启动脚本作为默认命令
CMD ["/app/start.sh"]

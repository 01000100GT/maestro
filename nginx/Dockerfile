FROM nginx:alpine

# 功能说明: Nginx Docker 镜像构建文件。此文件定义了如何构建 MAESTRO 应用程序的 Nginx 代理 Docker 镜像，包括移除默认配置、复制自定义配置以及暴露端口。

# 移除默认的 Nginx 配置
RUN rm /etc/nginx/conf.d/default.conf

# 复制我们完整的 Nginx 配置，它将替换主配置
COPY nginx.conf.complete /etc/nginx/nginx.conf

# 暴露端口 80
EXPOSE 80

# 启动 Nginx
CMD ["nginx", "-g", "daemon off;"]
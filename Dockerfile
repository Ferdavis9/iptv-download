FROM alpine:latest

# 安装依赖
RUN apk add --no-cache wget curl bash

# 创建脚本目录
WORKDIR /app

# 复制脚本
COPY download_m3u.sh /app/
RUN chmod +x /app/download_m3u.sh

# 设置定时任务
RUN echo "0 2 * * * /app/download_m3u.sh" > /etc/crontabs/root

# 启动crond
CMD ["crond", "-f", "-l", "2"]

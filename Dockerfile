FROM alpine:3.18

# 安装wget和其他依赖
RUN apk add --no-cache \
    wget \
    bash \
    coreutils

# 创建应用目录
WORKDIR /app

# 复制脚本文件
COPY download_script.sh /app/
RUN chmod +x /app/download_script.sh

# 创建数据目录
RUN mkdir -p /data

# 设置环境变量默认值
ENV DOWNLOAD_URL="https://bc.188766.xyz/?ip=&mishitong=true&mima=mianfeibuhuaqian&huikan=1"
ENV INTERVAL_HOURS=24
ENV RETENTION_DAYS=30
ENV DOWNLOAD_DIR="/data"

# 设置卷
VOLUME ["/data"]

# 启动脚本
CMD ["/app/download_script.sh"]

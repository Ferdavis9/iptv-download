#!/bin/bash

URL="https://bc.188766.xyz/?ip=&mishitong=true&mima=mianfeibuhuaqian&huikan=1"
DOWNLOAD_DIR="/data"
BACKUP_DAYS=30

# 生成带时间戳的文件名
FILENAME="iptv_$(date +%Y%m%d_%H%M%S).m3u"
FILEPATH="$DOWNLOAD_DIR/$FILENAME"

echo "$(date): 开始下载M3U文件"

# 下载文件
wget -O "$FILEPATH" "$URL"

if [ $? -eq 0 ] && [ -s "$FILEPATH" ]; then
    echo "$(date): 下载成功 - $FILENAME"
    
    # 清理旧文件
    find "$DOWNLOAD_DIR" -name "iptv_*.m3u" -mtime +$BACKUP_DAYS -delete
    echo "$(date): 已清理$BACKUP_DAYS天前的旧文件"
else
    echo "$(date): 下载失败"
    rm -f "$FILEPATH"
fi

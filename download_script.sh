#!/bin/bash

# 设置环境变量默认值
DOWNLOAD_URL=${DOWNLOAD_URL:-"https://bc.188766.xyz/?ip=&mishitong=true&mima=mianfeibuhuaqian&huikan=1"}
INTERVAL_HOURS=${INTERVAL_HOURS:-24}
RETENTION_DAYS=${RETENTION_DAYS:-30}
DOWNLOAD_DIR=${DOWNLOAD_DIR:-"/data"}

# 创建下载目录
mkdir -p "$DOWNLOAD_DIR"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# 下载m3u文件
download_m3u() {
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local filename="playlist_${timestamp}.m3u"
    local filepath="${DOWNLOAD_DIR}/${filename}"
    
    log "开始下载m3u文件..."
    log "下载URL: $DOWNLOAD_URL"
    log "保存路径: $filepath"
    
    # 使用curl下载文件
    if curl -s -f -L "$DOWNLOAD_URL" -o "$filepath"; then
        if [ -s "$filepath" ]; then
            log "下载成功: $filename"
            # 检查文件内容
            local file_size=$(wc -c < "$filepath")
            local line_count=$(wc -l < "$filepath")
            log "文件大小: ${file_size} bytes, 行数: ${line_count}"
        else
            log "警告: 下载的文件为空"
            rm -f "$filepath"
            return 1
        fi
    else
        log "错误: 下载失败 - curl退出代码: $?"
        return 1
    fi
}

# 清理旧文件
cleanup_old_files() {
    log "开始清理超过${RETENTION_DAYS}天的旧文件..."
    local deleted_count=0
    
    # 查找并删除超过保留期限的m3u文件
    while IFS= read -r -d '' file; do
        if [ -n "$file" ]; then
            log "删除旧文件: $(basename "$file")"
            rm -f "$file"
            ((deleted_count++))
        fi
    done < <(find "$DOWNLOAD_DIR" -name "*.m3u" -mtime "+${RETENTION_DAYS}" -print0)
    
    log "清理完成，删除了 ${deleted_count} 个文件"
}

# 主循环
main() {
    log "=== M3U下载器启动 ==="
    log "配置参数:"
    log "下载间隔: ${INTERVAL_HOURS}小时"
    log "文件保留: ${RETENTION_DAYS}天"
    log "下载目录: ${DOWNLOAD_DIR}"
    log "===================="
    
    # 立即执行一次下载
    download_m3u
    
    while true; do
        local next_run=$(date -d "+${INTERVAL_HOURS} hours" '+%Y-%m-%d %H:%M:%S')
        log "下一次下载时间: ${next_run}"
        log "等待 ${INTERVAL_HOURS} 小时..."
        
        # 等待指定小时数
        sleep "${INTERVAL_HOURS}h"
        
        log "开始定时下载任务..."
        
        # 执行下载
        if download_m3u; then
            log "下载任务成功完成"
        else
            log "下载任务失败，将在下次重试"
        fi
        
        # 清理旧文件
        cleanup_old_files
    done
}

# 捕获终止信号，优雅退出
trap "log '收到终止信号，正在退出...'; exit 0" SIGTERM SIGINT

# 启动主函数
main

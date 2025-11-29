#!/bin/bash

# 设置环境变量默认值
DOWNLOAD_URL=${DOWNLOAD_URL:-"https://bc.188766.xyz/?ip=&mishitong=true&mima=mianfeibuhuaqian&huikan=1"}
INTERVAL_HOURS=${INTERVAL_HOURS:-24}
RETENTION_DAYS=${RETENTION_DAYS:-30}
DOWNLOAD_DIR=${DOWNLOAD_DIR:-"/data"}

# 设置时区（确保使用中国时间）
export TZ=${TZ:-"Asia/Shanghai"}

# 显示当前容器时间（用于调试）
echo "容器当前时间: $(date)"
echo "容器时区设置: $TZ"

# 创建下载目录
mkdir -p "$DOWNLOAD_DIR"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# 检查wget是否可用
check_wget() {
    if ! command -v wget &> /dev/null; then
        log "错误: wget 未安装"
        exit 1
    fi
}

# 重命名现有playlist.m3u文件
rename_existing_playlist() {
    local playlist_path="${DOWNLOAD_DIR}/playlist.m3u"
    
    if [ -f "$playlist_path" ]; then
        # 获取文件的修改时间（月日格式）- 使用中国时区
        local file_date=$(date -r "$playlist_path" '+%m%d')
        local new_filename="playlist${file_date}.m3u"
        local new_filepath="${DOWNLOAD_DIR}/${new_filename}"
        
        # 检查是否已存在同名文件，如果存在则添加时间戳
        if [ -f "$new_filepath" ]; then
            local timestamp=$(date -r "$playlist_path" '+%m%d%H%M')
            new_filename="playlist${timestamp}.m3u"
            new_filepath="${DOWNLOAD_DIR}/${new_filename}"
        fi
        
        mv "$playlist_path" "$new_filepath"
        log "已重命名原有文件: playlist.m3u -> ${new_filename}"
    fi
}

# 下载m3u文件
download_m3u() {
    local filename="playlist.m3u"
    local filepath="${DOWNLOAD_DIR}/${filename}"
    local temp_filepath="${filepath}.tmp"
    
    log "开始下载m3u文件..."
    log "下载URL: $DOWNLOAD_URL"
    log "保存路径: $filepath"
    
    # 首先重命名现有的playlist.m3u文件
    rename_existing_playlist
    
    # 使用wget下载文件到临时文件
    if wget -q --timeout=30 --tries=3 -O "$temp_filepath" "$DOWNLOAD_URL"; then
        if [ -s "$temp_filepath" ]; then
            # 验证文件内容
            if head -n1 "$temp_filepath" | grep -q "^#EXTM3U"; then
                log "文件格式验证: 有效的M3U文件"
                # 移动临时文件到正式文件
                mv "$temp_filepath" "$filepath"
                log "下载成功: $filename"
                
                # 检查文件内容
                local file_size=$(wc -c < "$filepath")
                local line_count=$(wc -l < "$filepath")
                log "文件大小: ${file_size} bytes, 行数: ${line_count}"
                
                # 记录文件修改时间（中国时区）
                local file_mtime=$(date -r "$filepath" '+%Y-%m-%d %H:%M:%S')
                log "文件修改时间: ${file_mtime} (中国标准时间)"
            else
                log "警告: 下载的文件不是标准M3U格式，已丢弃"
                rm -f "$temp_filepath"
                return 1
            fi
        else
            log "警告: 下载的文件为空"
            rm -f "$temp_filepath"
            return 1
        fi
    else
        log "错误: wget下载失败 - 退出代码: $?"
        rm -f "$temp_filepath"
        return 1
    fi
}

# 清理旧文件
cleanup_old_files() {
    log "开始清理超过${RETENTION_DAYS}天的旧文件..."
    local deleted_count=0
    
    # 查找并删除超过保留期限的m3u文件（不包括当前的playlist.m3u）
    while IFS= read -r -d '' file; do
        if [ -n "$file" ] && [ "$(basename "$file")" != "playlist.m3u" ]; then
            local file_date=$(stat -c %y "$file" 2>/dev/null | cut -d' ' -f1 || echo "未知日期")
            local file_age=$(find "$file" -mtime "+${RETENTION_DAYS}" 2>/dev/null | wc -l)
            
            if [ "$file_age" -eq 1 ]; then
                log "删除旧文件: $(basename "$file") (创建于: $file_date)"
                rm -f "$file"
                ((deleted_count++))
            fi
        fi
    done < <(find "$DOWNLOAD_DIR" -maxdepth 1 -name "playlist*.m3u" -print0 2>/dev/null)
    
    log "清理完成，删除了 ${deleted_count} 个文件"
    
    # 显示当前保留的文件
    local remaining_files=$(find "$DOWNLOAD_DIR" -maxdepth 1 -name "playlist*.m3u" | wc -l)
    log "当前保留的文件数: ${remaining_files} 个"
    
    # 列出所有保留的文件（使用中国时区显示）
    if [ "$remaining_files" -gt 0 ]; then
        log "当前保留的文件列表:"
        find "$DOWNLOAD_DIR" -maxdepth 1 -name "playlist*.m3u" -exec sh -c '
            for file; do
                echo "  - $(basename "$file") (修改时间: $(TZ=Asia/Shanghai date -r "$file" +"%Y-%m-%d %H:%M:%S"))"
            done
        ' sh {} + | sort
    fi
}

# 显示当前配置
show_config() {
    log "=== M3U下载器配置 ==="
    log "下载URL: $DOWNLOAD_URL"
    log "下载间隔: ${INTERVAL_HOURS}小时"
    log "文件保留: ${RETENTION_DAYS}天"
    log "下载目录: ${DOWNLOAD_DIR}"
    log "容器时区: $TZ"
    log "当前时间: $(date)"
    log "===================="
}

# 主循环
main() {
    log "M3U下载器启动"
    
    # 检查wget是否可用
    check_wget
    
    # 显示配置
    show_config
    
    # 立即执行一次下载和清理
    log "执行初始下载..."
    if download_m3u; then
        log "初始下载成功完成"
    else
        log "初始下载失败，将在下次重试"
    fi
    cleanup_old_files
    
    # 计算循环次数
    local cycle_count=0
    
    while true; do
        ((cycle_count++))
        local next_run=$(date -d "+${INTERVAL_HOURS} hours" '+%Y-%m-%d %H:%M:%S')
        log "第 ${cycle_count} 轮循环 - 下一次下载时间: ${next_run} (中国标准时间)"
        log "等待 ${INTERVAL_HOURS} 小时..."
        
        # 等待指定小时数
        sleep "${INTERVAL_HOURS}h"
        
        log "开始第 ${cycle_count} 轮下载任务..."
        
        # 执行下载
        if download_m3u; then
            log "下载任务成功完成"
        else
            log "下载任务失败，将在下次重试"
        fi
        
        # 清理旧文件
        cleanup_old_files
        
        log "第 ${cycle_count} 轮任务完成"
    done
}

# 捕获终止信号，优雅退出
trap "log '收到终止信号，正在退出...'; exit 0" SIGTERM SIGINT

# 启动主函数
main

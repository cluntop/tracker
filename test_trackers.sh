#!/bin/bash

# ================= 配置区域 =================
THREADS=100                 # 并发线程数 (根据网络状况调整，建议 50-100)
TIMEOUT=15                  # 单个连接超时时间 (秒)
OUTPUT_MAIN="trackers_best.txt"
OUTPUT_ARIA2="trackers_best_aria2.txt"
# ===========================================

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <file>"
    exit 1
fi

INPUT_FILE="$1"

# 检查依赖
if ! command -v xargs &> /dev/null; then
    echo "Error: xargs is required."
    exit 1
fi

# 核心检测函数 (将被导出供 xargs 调用)
check_tracker() {
    local tracker="$1"
    local timeout="$2"
    local protocol=$(echo "$tracker" | grep -oE '^[a-z]+')

    case $protocol in
        http|https)
            # 使用 curl 检测，-I 仅请求头部加快速度
            if curl -s -f -m "$timeout" "$tracker" &>/dev/null; then
                echo "$tracker"
            fi
            ;;
        udp)
            local host=$(echo "$tracker" | cut -d'/' -f3 | cut -d':' -f1)
            local port=$(echo "$tracker" | cut -d'/' -f3 | cut -d':' -f2)
            # nc 检测 UDP
            if nc -zuv -w "$timeout" "$host" "$port" &>/dev/null; then
                echo "$tracker"
            fi
            ;;
        wss)
            # 优先使用 wscat (如果你安装了 node-ws)，否则用 nc
            if command -v wscat &> /dev/null; then
                # wscat 连接测试
                if wscat -c "$tracker" --no-check -w "$timeout" -x '{"close": 1}' &>/dev/null; then
                     echo "$tracker"
                fi
            else
                # 回退到 TCP 端口测试
                local host=$(echo "$tracker" | sed 's|wss://||' | cut -d'/' -f1)
                local port=$(echo "$host" | cut -d':' -f2)
                [ "$port" = "$host" ] && port=443 && host=$(echo "$host" | cut -d':' -f1)
                host=$(echo "$host" | cut -d':' -f1)
                
                if nc -zv -w "$timeout" "$host" "$port" &>/dev/null; then
                    echo "$tracker"
                fi
            fi
            ;;
    esac
}

# 导出函数和变量供子 shell 使用
export -f check_tracker
export TIMEOUT

echo "Starting Multi-threaded testing ($THREADS threads)..."
echo "Timeout set to ${TIMEOUT}s per tracker."

# 准备临时文件
TEMP_VALID_LIST=$(mktemp)

# ===========================================
# 1. 预处理 + 多线程并行执行
# ===========================================
# 逻辑：
# 1. 读取文件
# 2. 过滤黑名单
# 3. xargs -P 启动多线程
# 4. 将成功的结果写入临时文件
{
    if [ -f "blackstr.txt" ]; then
        grep -v -F -f blackstr.txt "$INPUT_FILE"
    else
        cat "$INPUT_FILE"
    fi
} | tr -d '\r' | sort -u | \
xargs -P "$THREADS" -I {} bash -c 'check_tracker "{}" "$TIMEOUT"' >> "$TEMP_VALID_LIST"

# ===========================================
# 2. 结果分类与文件生成
# ===========================================
echo "Testing complete. Categorizing results..."

# 清空旧文件
> "$OUTPUT_MAIN"
> "trackers_best_http.txt"
> "trackers_best_https.txt"
> "trackers_best_udp.txt"
> "trackers_best_wss.txt"

# 统计数量
count=0

if [ -s "$TEMP_VALID_LIST" ]; then
    # 保存总表
    sort -u "$TEMP_VALID_LIST" > "$OUTPUT_MAIN"
    
    # 分类保存
    grep "^http://"  "$OUTPUT_MAIN" > "trackers_best_http.txt"
    grep "^https://" "$OUTPUT_MAIN" > "trackers_best_https.txt"
    grep "^udp://"   "$OUTPUT_MAIN" > "trackers_best_udp.txt"
    grep "^wss://"   "$OUTPUT_MAIN" > "trackers_best_wss.txt"
    
    # 生成 Aria2 格式
    paste -sd "," "$OUTPUT_MAIN" > "$OUTPUT_ARIA2"
    
    count=$(wc -l < "$OUTPUT_MAIN")
else
    > "$OUTPUT_ARIA2"
fi

# 清理临时文件
rm "$TEMP_VALID_LIST"

echo "------------------------------------------------"
echo "Done! Found $count valid trackers."
echo "1. Standard list: $OUTPUT_MAIN"
echo "2. Aria2 format:  $OUTPUT_ARIA2"
echo "------------------------------------------------"

#!/bin/bash

# 检查是否提供了文件名作为参数
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <file>"
    exit 1
fi

input_file="$1"
# 输出文件定义
output_file_main="trackers_best.txt"
output_file_http="trackers_best_http.txt"
output_file_https="trackers_best_https.txt"
output_file_udp="trackers_best_udp.txt"
output_file_wss="trackers_best_wss.txt"
output_file_aria2="trackers_best_aria2.txt" # 新增 Aria2 输出文件

# 检查文件是否存在
if [ ! -f "$input_file" ]; then
    echo "Error: File not found."
    exit 1
fi

# 清空所有输出文件
> "$output_file_main"
> "$output_file_http"
> "$output_file_https"
> "$output_file_udp"
> "$output_file_wss"
> "$output_file_aria2"

echo "Starting connectivity test..."

# 过滤黑名单并开始循环
{
    if [ -f "blackstr.txt" ]; then
        grep -v -F -f blackstr.txt "$input_file"
    else
        cat "$input_file"
    fi
} | while IFS= read -r tracker; do
    # 忽略空行
    [ -z "$tracker" ] && continue

    protocol=$(echo "$tracker" | grep -oE '^[a-z]+')
    is_alive=0

    case $protocol in
        http)
            if curl -s -f -m 1 "$tracker" &>/dev/null; then
                echo -e "\033[32mSuccess\033[0m: $tracker"
                echo "$tracker" >> "$output_file_main"
                echo "$tracker" >> "$output_file_http"
                is_alive=1
            else
                echo -e "\033[31mFailed\033[0m: $tracker"
            fi
            ;;
        https)
            if curl -s -f -m 1 "$tracker" &>/dev/null; then
                echo -e "\033[32mSuccess\033[0m: $tracker"
                echo "$tracker" >> "$output_file_main"
                echo "$tracker" >> "$output_file_https"
                is_alive=1
            else
                echo -e "\033[31mFailed\033[0m: $tracker"
            fi
            ;;
        udp)
            host=$(echo "$tracker" | cut -d'/' -f3)
            port=$(echo "$host" | cut -d':' -f2)
            host=$(echo "$host" | cut -d':' -f1)
            # nc 增加 -w 1 超时
            if nc -zuv -w 1 "$host" "$port" &>/dev/null; then
                echo -e "\033[32mSuccess\033[0m: $tracker"
                echo "$tracker" >> "$output_file_main"
                echo "$tracker" >> "$output_file_udp"
                is_alive=1
            else
                echo -e "\033[31mFailed\033[0m: $tracker"
            fi
            ;;
        wss)
            host=$(echo "$tracker" | sed 's|wss://||' | cut -d'/' -f1)
            port=$(echo "$host" | cut -d':' -f2)
            if [ "$port" = "$host" ]; then
                port=443
                host=$(echo "$host" | cut -d':' -f1)
            else
                host=$(echo "$host" | cut -d':' -f1)
            fi
            
            if nc -zv -w 1 "$host" "$port" &>/dev/null; then
                echo -e "\033[32mSuccess\033[0m: $tracker"
                echo "$tracker" >> "$output_file_main"
                echo "$tracker" >> "$output_file_wss"
                is_alive=1
            else
                echo -e "\033[31mFailed\033[0m: $tracker"
            fi
            ;;
        *)
            echo "Unknown protocol: $protocol"
            ;;
    esac
done

# 生成 Aria2 格式 (将测试通过的列表合并为逗号分隔字符串)
if [ -s "$output_file_main" ]; then
    echo "Generating Aria2 format..."
    paste -sd "," "$output_file_main" > "$output_file_aria2"
fi

echo "Testing complete."
echo "Best trackers saved to $output_file_main"
echo "Aria2 format saved to $output_file_aria2"

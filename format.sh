#!/bin/bash

# =================配置区域=================
# 输出文件 1: 通用格式 (一行一个 URL)
output_file="formatted_trackers.txt"
# 输出文件 2: Aria2 格式 (逗号分隔，无换行)
output_file_aria2="trackers_all_aria2.txt"
# =========================================

# 1. 检查参数
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <file>"
    exit 1
fi

input_file="$1"

# 2. 检查输入文件
if [ ! -f "$input_file" ]; then
    echo "Error: File not found: $input_file"
    exit 1
fi

echo "Processing trackers..."

# 3. 处理核心逻辑
# - tr: 将逗号转为换行（兼容输入本身就是逗号分隔的情况）
# - grep: 提取 http/udp/wss 协议，自动忽略行内其他杂质（如 bt-tracker= 前缀）
# - sed: 去除默认端口 (80/443)，去除行尾空白
# - blackstr.txt: 黑名单过滤
# - sort -u: 去重并排序
tr ',' '\n' < "$input_file" | \
grep -oP '(http|https|udp|wss)://[^/]+/announce' | \
sed -E 's#(http://[^/]+):80/announce#\1/announce#; s#(https://[^/]+):443/announce#\1/announce#' | \
sed 's/[ \t]*$//' | \
{
    if [ -f "blackstr.txt" ]; then
        grep -v -F -f blackstr.txt
    else
        cat
    fi
} | sort -u > "$output_file"

# 4. 生成 Aria2 格式
# 检查第一个输出文件是否有内容
if [ -s "$output_file" ]; then
    # 使用 paste 命令将所有行合并为一行，用逗号分隔
    paste -sd "," "$output_file" > "$output_file_aria2"
else
    # 如果结果为空，清空 Aria2 文件
    > "$output_file_aria2"
    echo "Warning: No valid trackers found."
fi

# 5. 输出结果提示
echo "------------------------------------------------"
echo "Processing Complete."
echo ""
echo "1. [Standard Format] (Line-separated):"
echo "   -> $output_file"
echo ""
echo "2. [Aria2 Format] (Comma-separated):"
echo "   -> $output_file_aria2"
echo "------------------------------------------------"

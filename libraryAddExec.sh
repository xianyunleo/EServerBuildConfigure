#!/bin/bash

# 定义Library目录路径
LIBRARY_DIR="/Applications/EServer/Library"

# 遍历Library目录下的子目录
for dir in $LIBRARY_DIR/*; do
    # 判断子目录是否为目录
    if [ -d "$dir" ]; then
        # 获取子目录的bin目录路径
        BIN_DIR="$dir/bin"

        # 判断bin目录是否存在
        if [ -d "$BIN_DIR" ]; then
            # 给bin目录下的文件增加可执行权限
            chmod +x "$BIN_DIR"/*
        fi
    fi
done

echo "权限已经成功添加到bin目录下的文件。"

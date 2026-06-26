#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# 配置
# -------------------------------
# 脚本所在目录（项目根目录）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Library 根目录：默认指向项目内的 Library
# 如需作用于已部署的 /Applications/EServer/Library，可：
#   LIBRARY_DIR=/Applications/EServer/Library ./create-libs.sh
LIBRARY_DIR="${LIBRARY_DIR:-$SCRIPT_DIR/Library}"

# 统一的 pkgconfig 目录：把各子库 lib/pkgconfig 下的 .pc 文件
# 以符号链接形式集中到这里，方便 pkg-config 一次性搜索
TARGET_PKGCONFIG_DIR="$LIBRARY_DIR/lib/pkgconfig"

# -------------------------------
# 检测是否需要 sudo
# -------------------------------
if [ -w "$LIBRARY_DIR" ]; then
  SUDO=""
else
  SUDO="sudo"
fi

# -------------------------------
# 创建目标目录
# -------------------------------
$SUDO mkdir -p "$TARGET_PKGCONFIG_DIR"

# -------------------------------
# 遍历各子库，创建符号链接
# -------------------------------
# 排除 lib 目录本身，避免自引用 / 递归
linked_count=0
skipped_count=0

for sub_dir in "$LIBRARY_DIR"/*/; do
  [ -d "$sub_dir" ] || continue

  lib_name="$(basename "$sub_dir")"

  # 跳过目标 lib 目录本身
  if [ "$lib_name" = "lib" ]; then
    continue
  fi

  pkgconfig_dir="${sub_dir}lib/pkgconfig"
  if [ ! -d "$pkgconfig_dir" ]; then
    continue
  fi

  # 链接位于 $LIBRARY_DIR/lib/pkgconfig/ 下，
  # 相对源路径为 ../../<lib_name>/lib/pkgconfig/<file>
  for pc_file in "$pkgconfig_dir"/*; do
    [ -f "$pc_file" ] || continue

    pc_name="$(basename "$pc_file")"
    target_link="$TARGET_PKGCONFIG_DIR/$pc_name"
    rel_source="../../$lib_name/lib/pkgconfig/$pc_name"

    # 已存在（文件或链接）则先删除，保证指向最新
    if [ -e "$target_link" ] || [ -L "$target_link" ]; then
      $SUDO rm -f "$target_link"
    fi

    $SUDO ln -s "$rel_source" "$target_link"
    echo "linked: $pc_name  <-  $lib_name"
    linked_count=$((linked_count + 1))
  done
done

# -------------------------------
# 完成提示
# -------------------------------
echo "----------------------------------------"
echo "done: linked $linked_count file(s), skipped $skipped_count"
echo "target: $TARGET_PKGCONFIG_DIR"

#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------
# lz4 — 基于 Homebrew Formula/l/lz4.rb
# zstd 的 LZ4 支持依赖此库
# -------------------------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/Library/lz4}
LZ4_VERSION=${LZ4_VERSION:-1.10.0}

# -------------------------------------------------
# 下载源码
# -------------------------------------------------
TARBALL="lz4-${LZ4_VERSION}.tar.gz"
URL="https://github.com/lz4/lz4/archive/refs/tags/v${LZ4_VERSION}.tar.gz"

mkdir -p build
cd build

if [ ! -f "$TARBALL" ]; then
  echo "Downloading lz4 ${LZ4_VERSION}..."
  curl -fLo "$TARBALL" "$URL"
fi

# -------------------------------------------------
# 解压
# -------------------------------------------------
rm -rf "lz4-${LZ4_VERSION}"
tar -xzf "$TARBALL"
cd "lz4-${LZ4_VERSION}"

# -------------------------------------------------
# 编译安装（参照 Homebrew lz4 配方）
# lz4 使用 Makefile 而非 autotools
# -------------------------------------------------
make -j"$(sysctl -n hw.ncpu 2>/dev/null || echo 8)" PREFIX="$PREFIX"
sudo make install PREFIX="$PREFIX"

# 修复 pkgconfig 中的路径，避免硬编码构建路径
if [ -f "$PREFIX/lib/pkgconfig/liblz4.pc" ]; then
  sudo sed -i '' "s|^prefix=.*|prefix=$PREFIX|" "$PREFIX/lib/pkgconfig/liblz4.pc"
fi

# 删除 share 目录（不需要的文件）
if [ -d "$PREFIX/share" ]; then
  sudo rm -rf "$PREFIX/share"
fi

# -------------------------------------------------
# 完成提示
# -------------------------------------------------
echo "lz4 ${LZ4_VERSION} installed to $PREFIX"
ls -l "$PREFIX/lib"
ls -l "$PREFIX/include"

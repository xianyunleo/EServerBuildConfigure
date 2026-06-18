#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------
# libnghttp2 — 基于 Homebrew Formula/lib/libnghttp2.rb
# HTTP/2 C 库（与 nghttp2 同源，仅编译 lib 部分）
# -------------------------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/Library/libnghttp2}
NGHTTP2_VERSION=${NGHTTP2_VERSION:-1.69.0}

# -------------------------------------------------
# 下载源码
# -------------------------------------------------
TARBALL="nghttp2-${NGHTTP2_VERSION}.tar.gz"
URL="https://github.com/nghttp2/nghttp2/releases/download/v${NGHTTP2_VERSION}/${TARBALL}"

mkdir -p build
cd build

if [ ! -f "$TARBALL" ]; then
  echo "Downloading nghttp2 ${NGHTTP2_VERSION}..."
  curl -fLo "$TARBALL" "$URL"
fi

# -------------------------------------------------
# 解压
# -------------------------------------------------
rm -rf "nghttp2-${NGHTTP2_VERSION}"
tar -xzf "$TARBALL"
cd "nghttp2-${NGHTTP2_VERSION}"

# -------------------------------------------------
# 配置（参照 Homebrew libnghttp2 配方）
# --enable-lib-only : 仅编译 lib 部分，不编译命令行工具
# -------------------------------------------------
CFLAGS="-O2" \
CXXFLAGS="$CFLAGS" \
./configure \
  --prefix="$PREFIX" \
  --enable-lib-only

# -------------------------------------------------
# 编译安装（仅 lib 子目录）
# -------------------------------------------------
make -j"$(sysctl -n hw.ncpu 2>/dev/null || echo 8)" -C lib
sudo make -C lib install

# -------------------------------------------------
# 完成提示
# -------------------------------------------------
echo "libnghttp2 ${NGHTTP2_VERSION} installed to $PREFIX"
ls -l "$PREFIX/lib"
ls -l "$PREFIX/include"

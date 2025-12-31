#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# 配置
# -------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/Library/libjpeg-turbo}
JPEG_VERSION=${JPEG_VERSION:-2.1.5.1} # 可以根据需要修改版本

# -------------------------------
# 下载源码
# -------------------------------
TARBALL="libjpeg-turbo-${JPEG_VERSION}.tar.gz"
URL="https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/${JPEG_VERSION}/$TARBALL"

mkdir -p build
cd build

if [ ! -f "$TARBALL" ]; then
    echo "Downloading libjpeg-turbo $JPEG_VERSION..."
    curl -LO "$URL"
fi

# -------------------------------
# 解压并编译
# -------------------------------
rm -rf "libjpeg-turbo-${JPEG_VERSION}"
tar xf "$TARBALL"
cd "libjpeg-turbo-${JPEG_VERSION}"

# Autotools
if [ -f "./autogen.sh" ]; then
    ./autogen.sh
fi

# -------------------------------
# 配置
# -------------------------------
CFLAGS="-O2"
CXXFLAGS="$CFLAGS"
./configure \
    --prefix="$PREFIX" \
    --disable-silent-rules

# -------------------------------
# 编译安装
# -------------------------------
make -j$(sysctl -n hw.ncpu)
make install

# -------------------------------
# 打印完成信息
# -------------------------------
echo "libjpeg-turbo $JPEG_VERSION installed to $PREFIX"
ls -l "$PREFIX/lib"
ls -l "$PREFIX/include"

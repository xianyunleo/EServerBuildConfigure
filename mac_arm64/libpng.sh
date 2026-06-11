#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# 配置
# -------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/Library/libpng}
LIBPNG_VERSION=${LIBPNG_VERSION:-1.6.58}

# -------------------------------
# 下载源码
# -------------------------------
TARBALL="libpng-${LIBPNG_VERSION}.tar.gz"
URL="https://downloads.sourceforge.net/project/libpng/libpng16/${LIBPNG_VERSION}/$TARBALL"

mkdir -p build
cd build

if [ ! -f "$TARBALL" ]; then
    echo "Downloading libpng $LIBPNG_VERSION..."
    curl -LO "$URL"
fi

# -------------------------------
# 解压
# -------------------------------
rm -rf "libpng-${LIBPNG_VERSION}"
tar -xzf "$TARBALL"
cd "libpng-${LIBPNG_VERSION}"

# -------------------------------
# 清理旧文件
# -------------------------------
make clean || true

# -------------------------------
# 配置
# -------------------------------
CFLAGS="-O2"
CXXFLAGS="$CFLAGS"
./configure --prefix="$PREFIX" \
    --disable-silent-rules \
    --with-zlib-prefix=/Applications/EServer/Library/zlib

# -------------------------------
# 编译安装
# -------------------------------
make -j$(sysctl -n hw.ncpu)
sudo make install

# -------------------------------
# 完成提示
# -------------------------------
echo "libpng $LIBPNG_VERSION installed to $PREFIX"
ls -l "$PREFIX/lib"
ls -l "$PREFIX/include"

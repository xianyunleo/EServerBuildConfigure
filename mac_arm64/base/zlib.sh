#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# 配置
# -------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/Library/zlib}
ZLIB_VERSION=${ZLIB_VERSION:-1.3.1}

# -------------------------------
# 下载源码
# -------------------------------
TARBALL="zlib-${ZLIB_VERSION}.tar.gz"
URL="https://zlib.net/$TARBALL"

mkdir -p build
cd build

if [ ! -f "$TARBALL" ]; then
    echo "Downloading zlib $ZLIB_VERSION..."
    curl -LO "$URL"
fi

# -------------------------------
# 解压
# -------------------------------
rm -rf "zlib-${ZLIB_VERSION}"
tar -xzf "$TARBALL"
cd "zlib-${ZLIB_VERSION}"

# -------------------------------
# 清理旧文件
# -------------------------------
make clean || true

# -------------------------------
# 配置
# -------------------------------
export CFLAGS="-arch arm64"
./configure --prefix="$PREFIX"

# -------------------------------
# 编译安装
# -------------------------------
make -j8
make install

# -------------------------------
# 完成提示
# -------------------------------
echo "zlib $ZLIB_VERSION installed to $PREFIX"
ls -l "$PREFIX/lib"
ls -l "$PREFIX/include"

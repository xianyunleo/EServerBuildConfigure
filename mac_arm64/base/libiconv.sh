#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# 配置
# -------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/Library/libiconv}
LIBICONV_VERSION=${LIBICONV_VERSION:-1.17}

# -------------------------------
# 下载源码
# -------------------------------
TARBALL="libiconv-${LIBICONV_VERSION}.tar.gz"
URL="https://ftp.gnu.org/pub/gnu/libiconv/$TARBALL"

mkdir -p build
cd build

if [ ! -f "$TARBALL" ]; then
    echo "Downloading libiconv $LIBICONV_VERSION..."
    curl -LO "$URL"
fi

# -------------------------------
# 解压
# -------------------------------
rm -rf "libiconv-${LIBICONV_VERSION}"
tar -xzf "$TARBALL"
cd "libiconv-${LIBICONV_VERSION}"

# -------------------------------
# 清理旧文件
# -------------------------------
make clean || true

# -------------------------------
# 配置
# -------------------------------
export CFLAGS="-arch arm64"
./configure --prefix="$PREFIX" \
    --disable-debug \
    --disable-dependency-tracking \
    --enable-extra-encodings \
    --enable-static \
    --host=arm64-apple-darwin

# -------------------------------
# 编译安装
# -------------------------------
make -j8
make install

# -------------------------------
# 完成提示
# -------------------------------
echo "libiconv $LIBICONV_VERSION installed to $PREFIX"
ls -l "$PREFIX/lib"
ls -l "$PREFIX/include"

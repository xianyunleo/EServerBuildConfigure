#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# 配置
# -------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/Library/freetype}
FREETYPE_VERSION=${FREETYPE_VERSION:-2.13.3}

# -------------------------------
# 下载源码
# -------------------------------
TARBALL="freetype-${FREETYPE_VERSION}.tar.gz"
URL="https://download.savannah.gnu.org/releases/freetype/$TARBALL"

mkdir -p build
cd build

if [ ! -f "$TARBALL" ]; then
    echo "Downloading freetype $FREETYPE_VERSION..."
    curl -LO "$URL"
fi

# -------------------------------
# 解压
# -------------------------------
rm -rf "freetype-${FREETYPE_VERSION}"
tar -xzf "$TARBALL"
cd "freetype-${FREETYPE_VERSION}"

# -------------------------------
# 清理旧文件
# -------------------------------
make clean || true

# -------------------------------
# 配置
# -------------------------------
CFLAGS="-O2" \
CXXFLAGS="$CFLAGS" \
./configure --prefix="$PREFIX" \
    --enable-freetype-config \
    --without-harfbuzz \
    --without-brotli \
    BZIP2_CFLAGS="-I/Applications/EServer/Library/bzip2/include" \
    BZIP2_LIBS="-L/Applications/EServer/Library/bzip2/lib -lbz2" \
    PKG_CONFIG_PATH=/Applications/EServer/Library/libpng/lib/pkgconfig:/Applications/EServer/Library/zlib/lib/pkgconfig \
    --host=arm64-apple-darwin

# -------------------------------
# 编译安装
# -------------------------------
make -j8
make install

# -------------------------------
# 完成提示
# -------------------------------
echo "freetype $FREETYPE_VERSION installed to $PREFIX"
ls -l "$PREFIX/lib"
ls -l "$PREFIX/include"

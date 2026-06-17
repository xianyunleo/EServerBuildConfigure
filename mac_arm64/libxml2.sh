#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# 配置
# -------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/Library/libxml2}
LIBXML2_VERSION=${LIBXML2_VERSION:-2.13.5}

# -------------------------------
# 下载源码
# -------------------------------
TARBALL="libxml2-${LIBXML2_VERSION}.tar.xz"
URL="https://download.gnome.org/sources/libxml2/2.13/$TARBALL"

mkdir -p build
cd build

if [ ! -f "$TARBALL" ]; then
  echo "Downloading libxml2 $LIBXML2_VERSION..."
  curl -LO "$URL"
fi

# -------------------------------
# 解压
# -------------------------------
rm -rf "libxml2-${LIBXML2_VERSION}"
tar -xJf "$TARBALL"
cd "libxml2-${LIBXML2_VERSION}"

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
  --disable-dependency-tracking \
  --with-iconv=/Applications/EServer/Library/libiconv \
  --with-zlib=/Applications/EServer/Library/zlib \
  --with-history \
  --without-python \
  --without-lzma \
  --host=arm64-apple-darwin

# -------------------------------
# 编译安装
# -------------------------------
make -j8
make install

# -------------------------------
# 完成提示
# -------------------------------
echo "libxml2 $LIBXML2_VERSION installed to $PREFIX"
ls -l "$PREFIX/lib"
ls -l "$PREFIX/include"

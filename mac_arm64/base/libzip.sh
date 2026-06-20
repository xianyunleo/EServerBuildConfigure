#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# 配置
# -------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/Library/libzip}
LIBZIP_VERSION=${LIBZIP_VERSION:-1.11.4}
XZ_PREFIX=${XZ_PREFIX:-/Applications/EServer/Library/xz}
ZSTD_PREFIX=${ZSTD_PREFIX:-/Applications/EServer/Library/zstd}

# -------------------------------
# 下载源码
# -------------------------------
TARBALL="libzip-${LIBZIP_VERSION}.tar.xz"
URL="https://libzip.org/download/$TARBALL"

mkdir -p build
cd build

if [ ! -f "$TARBALL" ]; then
  echo "Downloading libzip $LIBZIP_VERSION..."
  curl -LO "$URL"
fi

# -------------------------------
# 解压
# -------------------------------
rm -rf "libzip-${LIBZIP_VERSION}"
tar -xJf "$TARBALL"
cd "libzip-${LIBZIP_VERSION}"

# -------------------------------
# 配置
# -------------------------------
cmake . -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_INSTALL_NAME_DIR="$PREFIX/lib" \
  -DCMAKE_SKIP_RPATH=ON \
  -DCMAKE_PREFIX_PATH="$XZ_PREFIX;$ZSTD_PREFIX" \
  -DZLIB_LIBRARY_RELEASE=/Applications/EServer/Library/zlib/lib/libz.dylib \
  -DBZIP2_LIBRARY_RELEASE=/Applications/EServer/Library/bzip2/lib/libbz2.a \
  -DCMAKE_C_FLAGS="-arch arm64" \
  -DCMAKE_CXX_FLAGS="-arch arm64" \
  -DENABLE_LZMA=ON \
  -DENABLE_ZSTD=ON \
  -DENABLE_GNUTLS=OFF \
  -DENABLE_MBEDTLS=OFF \
  -DENABLE_OPENSSL=OFF \
  -DBUILD_REGRESS=OFF \
  -DBUILD_EXAMPLES=OFF

# -------------------------------
# 编译安装
# -------------------------------
make -j8
sudo make install

# 删除 share 目录（不需要的文件）
if [ -d "$PREFIX/share" ]; then
  sudo rm -rf "$PREFIX/share"
fi

# -------------------------------
# 完成提示
# -------------------------------
echo "libzip $LIBZIP_VERSION installed to $PREFIX"
ls -l "$PREFIX/lib"
ls -l "$PREFIX/include"

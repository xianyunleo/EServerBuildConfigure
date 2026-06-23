#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# 配置
# -------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/Library/nghttp2}
NGHTTP2_VERSION=${NGHTTP2_VERSION:-1.64.0}

# -------------------------------
# 下载源码
# -------------------------------
TARBALL="nghttp2-${NGHTTP2_VERSION}.tar.gz"
URL="https://github.com/nghttp2/nghttp2/releases/download/v${NGHTTP2_VERSION}/$TARBALL"

mkdir -p build
cd build

if [ ! -f "$TARBALL" ]; then
  echo "Downloading nghttp2 $NGHTTP2_VERSION..."
  curl -LO "$URL"
fi

# -------------------------------
# 解压
# -------------------------------
rm -rf "nghttp2-${NGHTTP2_VERSION}"
tar -xzf "$TARBALL"
cd "nghttp2-${NGHTTP2_VERSION}"

# -------------------------------
# 清理旧文件
# -------------------------------
make clean || true

# -------------------------------
# 配置
# -------------------------------
OPENSSL_PREFIX="/Applications/EServer/Library/openssl@3.5"
PKG_CONFIG_PATH="$OPENSSL_PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH" \
CFLAGS="-O2" \
CXXFLAGS="-O2" \
./configure \
  --prefix="$PREFIX" \
  --enable-lib-only \
  --host=arm64-apple-darwin \
  --with-openssl="$OPENSSL_PREFIX"

# -------------------------------
# 编译安装
# -------------------------------
make -j"$(sysctl -n hw.ncpu 2>/dev/null || echo 8)"
make install

# -------------------------------
# 完成提示
# -------------------------------
echo "nghttp2 $NGHTTP2_VERSION installed to $PREFIX"
ls -l "$PREFIX/lib"
ls -l "$PREFIX/include"

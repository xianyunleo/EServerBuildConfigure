#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# 配置
# -------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/Library/curl}
CURL_VERSION=${CURL_VERSION:-8.11.1}

# -------------------------------
# 下载源码
# -------------------------------
TARBALL="curl-${CURL_VERSION}.tar.gz"
URL="https://curl.se/download/$TARBALL"

mkdir -p build
cd build

if [ ! -f "$TARBALL" ]; then
  echo "Downloading curl $CURL_VERSION..."
  curl -LO "$URL"
fi

# -------------------------------
# 解压
# -------------------------------
rm -rf "curl-${CURL_VERSION}"
tar -xzf "$TARBALL"
cd "curl-${CURL_VERSION}"

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
  --disable-debug \
  --disable-dependency-tracking \
  --disable-silent-rules \
  --with-ssl=/Applications/EServer/Library/openssl@3.5 \
  --with-zlib=/Applications/EServer/Library/zlib \
  --without-ca-bundle \
  --without-ca-path \
  --with-ca-fallback \
  --with-secure-transport \
  --with-default-ssl-backend=openssl \
  --with-nghttp2=/Applications/EServer/Library/nghttp2 \
  --without-libpsl \
  --without-libidn2 \
  --without-librtmp \
  --without-zstd \
  --without-brotli \
  --with-gssapi \
  --host=arm64-apple-darwin

# -------------------------------
# 编译安装
# -------------------------------
make -j8
make install

# -------------------------------
# 完成提示
# -------------------------------
echo "curl $CURL_VERSION installed to $PREFIX"
ls -l "$PREFIX/bin"
ls -l "$PREFIX/lib"

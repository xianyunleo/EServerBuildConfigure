#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------
# curl — 基于 Homebrew Formula/c/curl.rb
# 依赖: openssl, brotli, libnghttp2, libnghttp3, libngtcp2, libssh2, zstd, pkgconf
# -------------------------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/Library/curl}
CURL_VERSION=${CURL_VERSION:-8.20.0}

# 依赖库路径（按需覆盖）
OPENSSL_PREFIX=${OPENSSL_PREFIX:-/Applications/EServer/Library/openssl@3.5}
BROTLI_PREFIX=${BROTLI_PREFIX:-/Applications/EServer/Library/brotli}
LIBNGHTTP2_PREFIX=${LIBNGHTTP2_PREFIX:-/Applications/EServer/Library/libnghttp2}
LIBNGHTTP3_PREFIX=${LIBNGHTTP3_PREFIX:-/Applications/EServer/Library/libnghttp3}
LIBNGTCP2_PREFIX=${LIBNGTCP2_PREFIX:-/Applications/EServer/Library/libngtcp2}
LIBSSH2_PREFIX=${LIBSSH2_PREFIX:-/Applications/EServer/Library/libssh2}
ZSTD_PREFIX=${ZSTD_PREFIX:-/Applications/EServer/Library/zstd}
PKGCONF_PREFIX=${PKGCONF_PREFIX:-/Applications/EServer/Library/pkgconf}

# 设置 pkg-config 搜索路径，让 configure 自动发现依赖库
export PKG_CONFIG_PATH="\
${OPENSSL_PREFIX}/lib/pkgconfig:\
${BROTLI_PREFIX}/lib/pkgconfig:\
${LIBNGHTTP2_PREFIX}/lib/pkgconfig:\
${LIBNGHTTP3_PREFIX}/lib/pkgconfig:\
${LIBNGTCP2_PREFIX}/lib/pkgconfig:\
${LIBSSH2_PREFIX}/lib/pkgconfig:\
${ZSTD_PREFIX}/lib/pkgconfig\
${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"

# 确保 pkgconf 在 PATH 中
export PATH="$PKGCONF_PREFIX/bin:$PATH"

# -------------------------------------------------
# 下载源码
# -------------------------------------------------
TARBALL="curl-${CURL_VERSION}.tar.bz2"
URL="https://curl.se/download/${TARBALL}"

mkdir -p build
cd build

if [ ! -f "$TARBALL" ]; then
  echo "Downloading curl ${CURL_VERSION}..."
  curl -fLo "$TARBALL" "$URL"
fi

# -------------------------------------------------
# 解压
# -------------------------------------------------
rm -rf "curl-${CURL_VERSION}"
tar -xjf "$TARBALL"
cd "curl-${CURL_VERSION}"

# -------------------------------------------------
# 配置（参照 Homebrew curl 配方）
# -------------------------------------------------
# 基础参数
ARGS=(
  --prefix="$PREFIX"
  --disable-silent-rules
  --with-ssl="$OPENSSL_PREFIX"
  --without-ca-bundle
  --without-ca-path
  --with-ca-fallback
  --with-default-ssl-backend=openssl
  --with-libssh2
  --with-nghttp3
  --with-ngtcp2
  --without-libpsl
)

# macOS 专有参数
ARGS+=(
  --with-apple-sectrust
  --with-gssapi
)

# macOS Ventura+ 使用 Apple 内置 IDN，无需 libidn2
ARGS+=(
  --with-apple-idn
  --without-libidn2
)

# brotli / zstd / nghttp2 通过 pkg-config 自动发现，但也可显式指定路径
ARGS+=(
  --with-brotli="$BROTLI_PREFIX"
  --with-zstd="$ZSTD_PREFIX"
  --with-nghttp2="$LIBNGHTTP2_PREFIX"
)

CFLAGS="-O2" \
CXXFLAGS="$CFLAGS" \
./configure "${ARGS[@]}"

# -------------------------------------------------
# 编译安装
# -------------------------------------------------
make -j"$(sysctl -n hw.ncpu 2>/dev/null || echo 8)"
sudo make install

# -------------------------------------------------
# 完成提示
# -------------------------------------------------
echo "curl ${CURL_VERSION} installed to $PREFIX"
echo ""
echo "=== Linked features ==="
"$PREFIX/bin/curl-config" --features 2>/dev/null || true
echo ""
echo "=== Linked protocols ==="
"$PREFIX/bin/curl-config" --protocols 2>/dev/null || true
echo ""
ls -l "$PREFIX/bin"
ls -l "$PREFIX/lib"

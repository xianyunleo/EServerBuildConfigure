#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------
# libssh2 — 基于 Homebrew Formula/lib/libssh2.rb
# 依赖: openssl@3
# -------------------------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/Library/libssh2}
LIBSSH2_VERSION=${LIBSSH2_VERSION:-1.11.1}
OPENSSL_PREFIX=${OPENSSL_PREFIX:-/Applications/EServer/Library/openssl}

# -------------------------------------------------
# 下载源码
# -------------------------------------------------
TARBALL="libssh2-${LIBSSH2_VERSION}.tar.gz"
URL="https://libssh2.org/download/${TARBALL}"

mkdir -p build
cd build

if [ ! -f "$TARBALL" ]; then
  echo "Downloading libssh2 ${LIBSSH2_VERSION}..."
  curl -fLo "$TARBALL" "$URL"
fi

# -------------------------------------------------
# 解压
# -------------------------------------------------
rm -rf "libssh2-${LIBSSH2_VERSION}"
tar -xzf "$TARBALL"
cd "libssh2-${LIBSSH2_VERSION}"

# -------------------------------------------------
# 配置（参照 Homebrew libssh2 配方）
# -------------------------------------------------
# --with-openssl : 启用 OpenSSL 支持
# --with-libz    : 启用 zlib 支持（使用系统自带）
# --with-libssl-prefix : 指定 OpenSSL 安装路径
CFLAGS="-O2" \
CXXFLAGS="$CFLAGS" \
./configure \
  --prefix="$PREFIX" \
  --disable-silent-rules \
  --disable-examples-build \
  --with-openssl \
  --with-libz \
  --with-libssl-prefix="$OPENSSL_PREFIX"

# -------------------------------------------------
# 编译安装
# -------------------------------------------------
make -j"$(sysctl -n hw.ncpu 2>/dev/null || echo 8)"
sudo make install

# -------------------------------------------------
# 完成提示
# -------------------------------------------------
echo "libssh2 ${LIBSSH2_VERSION} installed to $PREFIX"
ls -l "$PREFIX/lib"
ls -l "$PREFIX/include"

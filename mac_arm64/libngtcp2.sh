#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------
# libngtcp2 — 基于 Homebrew Formula/lib/libngtcp2.rb
# IETF QUIC 协议实现
# 依赖: openssl@3, pkgconf (构建时)
# -------------------------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/Library/libngtcp2}
NGTCP2_VERSION=${NGTCP2_VERSION:-1.23.0}
OPENSSL_PREFIX=${OPENSSL_PREFIX:-/Applications/EServer/Library/openssl@3.5}

# -------------------------------------------------
# 下载源码
# -------------------------------------------------
TARBALL="ngtcp2-${NGTCP2_VERSION}.tar.xz"
URL="https://github.com/ngtcp2/ngtcp2/releases/download/v${NGTCP2_VERSION}/${TARBALL}"

mkdir -p build
cd build

if [ ! -f "$TARBALL" ]; then
  echo "Downloading ngtcp2 ${NGTCP2_VERSION}..."
  curl -fLo "$TARBALL" "$URL"
fi

# -------------------------------------------------
# 解压
# -------------------------------------------------
rm -rf "ngtcp2-${NGTCP2_VERSION}"
tar -xJf "$TARBALL"
cd "ngtcp2-${NGTCP2_VERSION}"

# -------------------------------------------------
# 配置（参照 Homebrew libngtcp2 配方）
# ngtcp2 通过 pkg-config 自动查找 OpenSSL
# -------------------------------------------------
export PKG_CONFIG_PATH="$OPENSSL_PREFIX/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"

CFLAGS="-O2" \
CXXFLAGS="$CFLAGS" \
./configure \
  --prefix="$PREFIX" \
  --disable-silent-rules

# -------------------------------------------------
# 编译安装
# -------------------------------------------------
make -j"$(sysctl -n hw.ncpu 2>/dev/null || echo 8)"
sudo make install

# 删除 share 目录（不需要的文件）
if [ -d "$PREFIX/share" ]; then
  sudo rm -rf "$PREFIX/share"
fi

# -------------------------------------------------
# 完成提示
# -------------------------------------------------
echo "libngtcp2 ${NGTCP2_VERSION} installed to $PREFIX"
ls -l "$PREFIX/lib"
ls -l "$PREFIX/include"

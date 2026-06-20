#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------
# libnghttp3 — 基于 Homebrew Formula/lib/libnghttp3.rb
# HTTP/3 C 库（QUIC 传输层之上的 HTTP/3 协议实现）
# -------------------------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/Library/libnghttp3}
NGHTTP3_VERSION=${NGHTTP3_VERSION:-1.16.0}

# -------------------------------------------------
# 下载源码
# -------------------------------------------------
TARBALL="nghttp3-${NGHTTP3_VERSION}.tar.xz"
URL="https://github.com/ngtcp2/nghttp3/releases/download/v${NGHTTP3_VERSION}/${TARBALL}"

mkdir -p build
cd build

if [ ! -f "$TARBALL" ]; then
  echo "Downloading nghttp3 ${NGHTTP3_VERSION}..."
  curl -fLo "$TARBALL" "$URL"
fi

# -------------------------------------------------
# 解压
# -------------------------------------------------
rm -rf "nghttp3-${NGHTTP3_VERSION}"
tar -xJf "$TARBALL"
cd "nghttp3-${NGHTTP3_VERSION}"

# -------------------------------------------------
# 配置（参照 Homebrew libnghttp3 配方）
# -DENABLE_LIB_ONLY=1 : 仅编译库文件
# -------------------------------------------------
cmake -S . -B build \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_INSTALL_NAME_DIR="$PREFIX/lib" \
  -DCMAKE_SKIP_RPATH=ON \
  -DCMAKE_OSX_ARCHITECTURES="arm64" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET}" \
  -DENABLE_LIB_ONLY=1

# -------------------------------------------------
# 编译安装
# -------------------------------------------------
cmake --build build --parallel "$(sysctl -n hw.ncpu 2>/dev/null || echo 8)"
sudo cmake --install build

# -------------------------------------------------
# 完成提示
# -------------------------------------------------
echo "libnghttp3 ${NGHTTP3_VERSION} installed to $PREFIX"
ls -l "$PREFIX/lib"
ls -l "$PREFIX/include"

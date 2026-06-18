#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------
# brotli — 基于 Homebrew Formula/b/brotli.rb
# -------------------------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/Library/brotli}
BROTLI_VERSION=${BROTLI_VERSION:-1.2.0}

# -------------------------------------------------
# 下载源码
# -------------------------------------------------
TARBALL="brotli-${BROTLI_VERSION}.tar.gz"
URL="https://github.com/google/brotli/archive/refs/tags/v${BROTLI_VERSION}.tar.gz"

mkdir -p build
cd build

if [ ! -f "$TARBALL" ]; then
  echo "Downloading brotli ${BROTLI_VERSION}..."
  curl -fLo "$TARBALL" "$URL"
fi

# -------------------------------------------------
# 解压
# -------------------------------------------------
rm -rf "brotli-${BROTLI_VERSION}"
tar -xzf "$TARBALL"
cd "brotli-${BROTLI_VERSION}"

# -------------------------------------------------
# 配置（参照 Homebrew brotli 配方）
# -------------------------------------------------
# 动态库构建
cmake -S . -B build \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_OSX_ARCHITECTURES="arm64" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET}" \
  -DCMAKE_INSTALL_RPATH="$PREFIX/lib"

# 编译安装动态库
cmake --build build --parallel "$(sysctl -n hw.ncpu 2>/dev/null || echo 8)"
sudo cmake --install build

# 静态库构建（参照 Homebrew 配方，单独构建静态库）
cmake -S . -B build-static \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_OSX_ARCHITECTURES="arm64" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET}" \
  -DBUILD_SHARED_LIBS=OFF

cmake --build build-static --parallel "$(sysctl -n hw.ncpu 2>/dev/null || echo 8)"
# 只复制静态库，不重复安装
cp build-static/libbrotli*.a "$PREFIX/lib/"

# -------------------------------------------------
# 完成提示
# -------------------------------------------------
echo "brotli ${BROTLI_VERSION} installed to $PREFIX"
ls -l "$PREFIX/lib"
ls -l "$PREFIX/include"

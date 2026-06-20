#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------
# zstd — 基于 Homebrew Formula/z/zstd.rb
# 依赖: lz4, xz
# -------------------------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/Library/zstd}
ZSTD_VERSION=${ZSTD_VERSION:-1.5.7}
LZ4_PREFIX=${LZ4_PREFIX:-/Applications/EServer/Library/lz4}
XZ_PREFIX=${XZ_PREFIX:-/Applications/EServer/Library/xz}

# -------------------------------------------------
# 下载源码
# -------------------------------------------------
TARBALL="zstd-${ZSTD_VERSION}.tar.gz"
URL="https://github.com/facebook/zstd/archive/refs/tags/v${ZSTD_VERSION}.tar.gz"

mkdir -p build
cd build

if [ ! -f "$TARBALL" ]; then
  echo "Downloading zstd ${ZSTD_VERSION}..."
  curl -fLo "$TARBALL" "$URL"
fi

# -------------------------------------------------
# 解压
# -------------------------------------------------
rm -rf "zstd-${ZSTD_VERSION}"
tar -xzf "$TARBALL"
cd "zstd-${ZSTD_VERSION}"

# -------------------------------------------------
# 配置（参照 Homebrew zstd 配方）
# -------------------------------------------------
# cmake 构建在 build/cmake 子目录
# -DZSTD_LEGACY_SUPPORT=ON : 兼容旧版格式
# -DZSTD_ZLIB_SUPPORT=ON   : 支持 zlib（使用系统自带）
# -DZSTD_LZMA_SUPPORT=ON   : 支持 LZMA/xz
# -DZSTD_LZ4_SUPPORT=ON    : 支持 LZ4
cmake -S build/cmake -B builddir \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_INSTALL_NAME_DIR="$PREFIX/lib" \
  -DCMAKE_SKIP_RPATH=ON \
  -DCMAKE_OSX_ARCHITECTURES="arm64" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET}" \
  -DCMAKE_PREFIX_PATH="$LZ4_PREFIX;$XZ_PREFIX" \
  -DBUILD_SHARED_LIBS=ON \
  -DZSTD_PROGRAMS_LINK_SHARED=ON \
  -DZSTD_BUILD_CONTRIB=ON \
  -DZSTD_LEGACY_SUPPORT=ON \
  -DZSTD_ZLIB_SUPPORT=ON \
  -DZSTD_LZMA_SUPPORT=ON \
  -DZSTD_LZ4_SUPPORT=ON \
  -DCMAKE_CXX_STANDARD=11

# -------------------------------------------------
# 编译安装
# -------------------------------------------------
cmake --build builddir --parallel "$(sysctl -n hw.ncpu 2>/dev/null || echo 8)"
sudo cmake --install builddir

# 修复 pkgconfig 中的绝对路径
if [ -f "$PREFIX/lib/pkgconfig/libzstd.pc" ]; then
  sudo sed -i '' "s|^prefix=.*|prefix=$PREFIX|" "$PREFIX/lib/pkgconfig/libzstd.pc"
fi

# 删除 share 目录（不需要的文件）
if [ -d "$PREFIX/share" ]; then
  sudo rm -rf "$PREFIX/share"
fi

# -------------------------------------------------
# 完成提示
# -------------------------------------------------
echo "zstd ${ZSTD_VERSION} installed to $PREFIX"
ls -l "$PREFIX/lib"
ls -l "$PREFIX/include"

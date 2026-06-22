#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------
# libwebp — 基于 Homebrew Formula/w/webp.rb
# 依赖: libpng, libjpeg-turbo
# -------------------------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/Library/libwebp}
LIBWEBP_VERSION=${LIBWEBP_VERSION:-1.6.0}

# 依赖库路径（按需覆盖）
LIBPNG_PREFIX=${LIBPNG_PREFIX:-/Applications/EServer/Library/libpng}
JPEG_PREFIX=${JPEG_PREFIX:-/Applications/EServer/Library/libjpeg-turbo}

# 依赖搜索路径（让 cmake find_package 找到 libpng / libjpeg-turbo）
DEPS_PREFIX="$LIBPNG_PREFIX;$JPEG_PREFIX"

# -------------------------------------------------
# 下载源码
# -------------------------------------------------
TARBALL="libwebp-${LIBWEBP_VERSION}.tar.gz"
URL="https://storage.googleapis.com/downloads.webmproject.org/releases/webp/$TARBALL"

mkdir -p build
cd build

if [ ! -f "$TARBALL" ]; then
  echo "Downloading libwebp $LIBWEBP_VERSION..."
  curl -fLo "$TARBALL" "$URL"
fi

# -------------------------------------------------
# 解压
# -------------------------------------------------
rm -rf "libwebp-${LIBWEBP_VERSION}"
tar -xzf "$TARBALL"
cd "libwebp-${LIBWEBP_VERSION}"

# -------------------------------------------------
# 动态库构建（参照 Homebrew webp 配方）
# -------------------------------------------------
sudo cmake -S . -B build \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_INSTALL_NAME_DIR="$PREFIX/lib" \
  -DCMAKE_SKIP_RPATH=ON \
  -DCMAKE_OSX_ARCHITECTURES="arm64" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET}" \
  -DCMAKE_INSTALL_RPATH="$PREFIX/lib" \
  -DCMAKE_PREFIX_PATH="$DEPS_PREFIX" \
  -DCMAKE_DISABLE_FIND_PACKAGE_GIF=ON \
  -DCMAKE_DISABLE_FIND_PACKAGE_TIFF=ON \
  -DBUILD_SHARED_LIBS=ON \
  -DWEBP_BUILD_GIF2WEBP=OFF \
  -DWEBP_BUILD_IMG2WEBP=OFF

sudo cmake --build build --parallel "$(sysctl -n hw.ncpu 2>/dev/null || echo 8)"
sudo cmake --install build

# 删除 share 目录（不需要的文件）
if [ -d "$PREFIX/share" ]; then
  sudo rm -rf "$PREFIX/share"
fi

# -------------------------------------------------
# 静态库构建（参照 Homebrew 配方，单独构建静态库）
# -------------------------------------------------
sudo cmake -S . -B build-static \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_INSTALL_NAME_DIR="$PREFIX/lib" \
  -DCMAKE_SKIP_RPATH=ON \
  -DCMAKE_OSX_ARCHITECTURES="arm64" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET}" \
  -DCMAKE_PREFIX_PATH="$DEPS_PREFIX" \
  -DCMAKE_DISABLE_FIND_PACKAGE_GIF=ON \
  -DCMAKE_DISABLE_FIND_PACKAGE_TIFF=ON \
  -DBUILD_SHARED_LIBS=OFF \
  -DWEBP_BUILD_GIF2WEBP=OFF \
  -DWEBP_BUILD_IMG2WEBP=OFF

sudo cmake --build build-static --parallel "$(sysctl -n hw.ncpu 2>/dev/null || echo 8)"
# 只复制静态库，不重复安装
sudo cp build-static/lib*.a "$PREFIX/lib/"

# -------------------------------------------------
# 完成提示
# -------------------------------------------------
echo "libwebp $LIBWEBP_VERSION installed to $PREFIX"
ls -l "$PREFIX/lib"
ls -l "$PREFIX/include"

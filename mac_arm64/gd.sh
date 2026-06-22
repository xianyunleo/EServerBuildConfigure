#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------
# gd — 基于 Homebrew Formula/g/gd.rb
# 依赖: freetype, libjpeg-turbo, libpng, libwebp
# -------------------------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/Library/gd}
GD_VERSION=${GD_VERSION:-2.3.3}

# 依赖库路径（按需覆盖）
FREETYPE_PREFIX=${FREETYPE_PREFIX:-/Applications/EServer/Library/freetype}
JPEG_PREFIX=${JPEG_PREFIX:-/Applications/EServer/Library/libjpeg-turbo}
LIBPNG_PREFIX=${LIBPNG_PREFIX:-/Applications/EServer/Library/libpng}
LIBWEBP_PREFIX=${LIBWEBP_PREFIX:-/Applications/EServer/Library/libwebp}

# -------------------------------------------------
# 下载源码
# -------------------------------------------------
TARBALL="libgd-${GD_VERSION}.tar.xz"
URL="https://github.com/libgd/libgd/releases/download/gd-${GD_VERSION}/$TARBALL"

mkdir -p build
cd build

if [ ! -f "$TARBALL" ]; then
  echo "Downloading libgd $GD_VERSION..."
  curl -fLo "$TARBALL" "$URL"
fi

# -------------------------------------------------
# 解压
# -------------------------------------------------
rm -rf "libgd-${GD_VERSION}"
tar -xf "$TARBALL"
cd "libgd-${GD_VERSION}"

# -------------------------------------------------
# 应用补丁（revert breaking changes in 2.3.3）
# -------------------------------------------------
PATCH_FILE="../../patch/libgd-2.3.3-bc.patch"
if [ -f "$PATCH_FILE" ]; then
  echo "Applying patch..."
  patch -p1 < "$PATCH_FILE"
fi

# -------------------------------------------------
# 清理旧文件
# -------------------------------------------------
make clean || true

# -------------------------------------------------
# 配置（参照 Homebrew gd 配方）
# -------------------------------------------------
CFLAGS="-O2" \
CXXFLAGS="$CFLAGS" \
CPPFLAGS="-I$FREETYPE_PREFIX/include -I$JPEG_PREFIX/include -I$LIBPNG_PREFIX/include -I$LIBWEBP_PREFIX/include" \
LDFLAGS="-L$FREETYPE_PREFIX/lib -L$JPEG_PREFIX/lib -L$LIBPNG_PREFIX/lib -L$LIBWEBP_PREFIX/lib" \
./configure --prefix="$PREFIX" \
  --with-freetype="$FREETYPE_PREFIX" \
  --with-jpeg="$JPEG_PREFIX" \
  --with-png="$LIBPNG_PREFIX" \
  --with-webp="$LIBWEBP_PREFIX" \
  --without-fontconfig \
  --without-avif \
  --without-tiff \
  --without-x \
  --without-xpm

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
echo "gd $GD_VERSION installed to $PREFIX"
ls -l "$PREFIX/lib"
ls -l "$PREFIX/include"

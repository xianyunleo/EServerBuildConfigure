#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------
# libwebp — WebP 图像编解码库
# 依赖: libpng, libjpeg-turbo
# -------------------------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/Library/libwebp}
LIBWEBP_VERSION=${LIBWEBP_VERSION:-1.6.0}

# 依赖库路径（按需覆盖）
LIBPNG_PREFIX=${LIBPNG_PREFIX:-/Applications/EServer/Library/libpng}
JPEG_PREFIX=${JPEG_PREFIX:-/Applications/EServer/Library/libjpeg-turbo}

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
# 清理旧文件
# -------------------------------------------------
make clean || true

# -------------------------------------------------
# 配置
# -------------------------------------------------
CFLAGS="-O2" \
CXXFLAGS="$CFLAGS" \
CPPFLAGS="-I$LIBPNG_PREFIX/include -I$JPEG_PREFIX/include" \
LDFLAGS="-L$LIBPNG_PREFIX/lib -L$JPEG_PREFIX/lib" \
./configure --prefix="$PREFIX" \
  --disable-tiff \
  --disable-gif \
  --with-pngincludedir="$LIBPNG_PREFIX/include" \
  --with-pnglibdir="$LIBPNG_PREFIX/lib" \
  --with-jpegincludedir="$JPEG_PREFIX/include" \
  --with-jpeglibdir="$JPEG_PREFIX/lib"

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
echo "libwebp $LIBWEBP_VERSION installed to $PREFIX"
ls -l "$PREFIX/lib"
ls -l "$PREFIX/include"

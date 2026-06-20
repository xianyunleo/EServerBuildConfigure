#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------
# freetype — 基于 Homebrew Formula/f/freetype.rb
# 依赖: libpng, brotli, bzip2, zlib
# -------------------------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/Library/freetype}
FREETYPE_VERSION=${FREETYPE_VERSION:-2.13.3}

# 依赖库路径（按需覆盖）
LIBPNG_PREFIX=${LIBPNG_PREFIX:-/Applications/EServer/Library/libpng}
BROTLI_PREFIX=${BROTLI_PREFIX:-/Applications/EServer/Library/brotli}
# zlib 使用系统版本，libpng 已静态链接 zlib，无需额外指定

export PKG_CONFIG_PATH="
$LIBPNG_PREFIX/lib/pkgconfig:
$BROTLI_PREFIX/lib/pkgconfig"
# -------------------------------------------------
# 下载源码
# -------------------------------------------------
TARBALL="freetype-${FREETYPE_VERSION}.tar.gz"
URL="https://download.savannah.gnu.org/releases/freetype/$TARBALL"

mkdir -p build
cd build

if [ ! -f "$TARBALL" ]; then
  echo "Downloading freetype $FREETYPE_VERSION..."
  curl -fLo "$TARBALL" "$URL"
fi

# -------------------------------------------------
# 解压
# -------------------------------------------------
rm -rf "freetype-${FREETYPE_VERSION}"
tar -xzf "$TARBALL"
cd "freetype-${FREETYPE_VERSION}"

# -------------------------------------------------
# 清理旧文件
# -------------------------------------------------
make clean || true

# -------------------------------------------------
# 配置（参照 Homebrew freetype 配方）
# -------------------------------------------------
CFLAGS="-O2" \
CXXFLAGS="$CFLAGS" \
./configure --prefix="$PREFIX" \
  --enable-freetype-config \
  --with-png \
  --with-brotli \
  --without-harfbuzz

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
echo "freetype $FREETYPE_VERSION installed to $PREFIX"
echo ""
echo "=== Configuration ==="
"$PREFIX/bin/freetype-config" --libs 2>/dev/null || true
echo ""
ls -l "$PREFIX/lib"
ls -l "$PREFIX/include"

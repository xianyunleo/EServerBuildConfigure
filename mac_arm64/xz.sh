#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------
# xz (liblzma) — 基于 Homebrew Formula/x/xz.rb
# zstd 的 LZMA 支持依赖此库
# -------------------------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/Library/xz}
XZ_VERSION=${XZ_VERSION:-5.8.3}

# -------------------------------------------------
# 下载源码
# -------------------------------------------------
TARBALL="xz-${XZ_VERSION}.tar.gz"
URL="https://github.com/tukaani-project/xz/releases/download/v${XZ_VERSION}/${TARBALL}"

mkdir -p build
cd build

if [ ! -f "$TARBALL" ]; then
  echo "Downloading xz ${XZ_VERSION}..."
  curl -fLo "$TARBALL" "$URL"
fi

# -------------------------------------------------
# 解压
# -------------------------------------------------
rm -rf "xz-${XZ_VERSION}"
tar -xzf "$TARBALL"
cd "xz-${XZ_VERSION}"

# -------------------------------------------------
# 配置（参照 Homebrew xz 配方）
# -------------------------------------------------
CFLAGS="-O2" \
CXXFLAGS="$CFLAGS" \
./configure \
  --prefix="$PREFIX" \
  --disable-silent-rules \
  --disable-nls

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
echo "xz ${XZ_VERSION} installed to $PREFIX"
ls -l "$PREFIX/lib"
ls -l "$PREFIX/include"

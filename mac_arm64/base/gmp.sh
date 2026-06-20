#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# 配置
# -------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/Library/gmp}
GMP_VERSION=${GMP_VERSION:-6.3.0} # 可以根据需要修改版本

# -------------------------------
# 下载 GMP 源码
# -------------------------------
GMP_TAR="gmp-$GMP_VERSION.tar.gz"
GMP_URL="https://ftpmirror.gnu.org/gnu/gmp/$GMP_TAR"

mkdir -p build
cd build

if [ ! -f "$GMP_TAR" ]; then
  echo "Downloading GMP $GMP_VERSION..."
  curl -LO "$GMP_URL"
fi

# -------------------------------
# 解压并编译
# -------------------------------
rm -rf "gmp-$GMP_VERSION"
tar xf "$GMP_TAR"

cd "gmp-$GMP_VERSION"

# 配置
CFLAGS="-O2"
CXXFLAGS="$CFLAGS"
./configure \
  --prefix="$PREFIX" \
  --enable-cxx \
  --with-pic

# 编译安装
make -j$(sysctl -n hw.ncpu)
make install

# 删除 share 目录（不需要的文件）
if [ -d "$PREFIX/share" ]; then
  sudo rm -rf "$PREFIX/share"
fi

# -------------------------------
# 打印完成信息
# -------------------------------
echo "GMP $GMP_VERSION installed to $PREFIX"
ls -l "$PREFIX/lib"
ls -l "$PREFIX/include"

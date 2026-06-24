#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# 配置
# -------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/Library/oniguruma}
ONIG_VERSION=${ONIG_VERSION:-6.9.10}

# -------------------------------
# 下载源码
# -------------------------------
TARBALL="onig-${ONIG_VERSION}.tar.gz"
URL="https://github.com/kkos/oniguruma/releases/download/v${ONIG_VERSION}/$TARBALL"

mkdir -p build
cd build

if [ ! -f "$TARBALL" ]; then
  echo "Downloading oniguruma $ONIG_VERSION..."
  curl -LO "$URL"
fi

# -------------------------------
# 解压
# -------------------------------
rm -rf "onig-${ONIG_VERSION}"
tar -xzf "$TARBALL"
cd "onig-${ONIG_VERSION}"

# -------------------------------
# 清理旧文件
# -------------------------------
make clean || true

# -------------------------------
# 配置
# -------------------------------
CFLAGS="-O2"
CXXFLAGS="$CFLAGS"
./configure --prefix="$PREFIX" \
  --disable-dependency-tracking

# -------------------------------
# 编译安装
# -------------------------------
make -j$(sysctl -n hw.ncpu)
sudo make install

# -------------------------------
# 完成提示
# -------------------------------
echo "oniguruma $ONIG_VERSION installed to $PREFIX"
ls -l "$PREFIX/lib"
ls -l "$PREFIX/include"

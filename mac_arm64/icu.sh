#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------
# 配置
# -------------------------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/Library/icu}
ICU_VERSION=${ICU_VERSION:-78.3}

# -------------------------------------------------
# 下载源码
# -------------------------------------------------
TARBALL="icu4c-${ICU_VERSION}-sources.tgz"
URL="https://github.com/unicode-org/icu/releases/download/release-${ICU_VERSION}/${TARBALL}"

mkdir -p "$PREFIX" build
cd build

if [ ! -f "$TARBALL" ]; then
  echo "Downloading ICU $ICU_VERSION..."
  curl -fL -o "$TARBALL" "$URL"
fi

# -------------------------------------------------
# 解压
# -------------------------------------------------
rm -rf icu
tar -xzf "$TARBALL"

# ICU 源码在 icu/source 目录
cd icu/source

# -------------------------------------------------
# 清理旧文件
# -------------------------------------------------
make clean 2>/dev/null || true

# -------------------------------------------------
# 配置
# -------------------------------------------------
CFLAGS="-O2" \
CXXFLAGS="$CFLAGS" \
./configure --prefix="$PREFIX" \
  --disable-samples \
  --disable-tests \
  --enable-static \
  --with-library-bits=64

# -------------------------------------------------
# 编译安装
# -------------------------------------------------
make -j"$(sysctl -n hw.ncpu 2>/dev/null || echo 8)"
make install

# -------------------------------------------------
# 完成提示
# -------------------------------------------------
echo "ICU $ICU_VERSION installed to $PREFIX"
ls -l "$PREFIX/lib"

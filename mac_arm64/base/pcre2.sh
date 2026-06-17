#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# 配置
# -------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/Library/pcre2}
PCRE2_VERSION=${PCRE2_VERSION:-10.47}

# -------------------------------
# 下载源码
# -------------------------------
TARBALL="pcre2-${PCRE2_VERSION}.tar.gz"
URL="https://github.com/PCRE2Project/pcre2/releases/download/pcre2-${PCRE2_VERSION}/$TARBALL"

mkdir -p build
cd build

if [ ! -f "$TARBALL" ]; then
  echo "Downloading pcre2 $PCRE2_VERSION..."
  curl -LO "$URL"
fi

# -------------------------------
# 解压
# -------------------------------
rm -rf "pcre2-${PCRE2_VERSION}"
tar -xzf "$TARBALL"
cd "pcre2-${PCRE2_VERSION}"

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
  --disable-dependency-tracking \
  --enable-pcre2-16 \
  --enable-pcre2-32 \
  --enable-pcre2grep-libz \
  --enable-pcre2grep-libbz2 \
  --enable-jit

# -------------------------------
# 编译安装
# -------------------------------
make -j$(sysctl -n hw.ncpu)
make install

# -------------------------------
# 完成提示
# -------------------------------
echo "pcre2 $PCRE2_VERSION installed to $PREFIX"
ls -l "$PREFIX/lib"
ls -l "$PREFIX/include"

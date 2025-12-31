#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# 配置
# -------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/Library/openssl@1.1}
OPENSSL_VERSION=${OPENSSL_VERSION:-1.1.1w}

# -------------------------------
# 下载源码
# -------------------------------
TARBALL="openssl-${OPENSSL_VERSION}.tar.gz"
URL="https://www.openssl.org/source/$TARBALL"

mkdir -p build
cd build

if [ ! -f "$TARBALL" ]; then
    echo "Downloading OpenSSL $OPENSSL_VERSION..."
    curl -LO "$URL"
fi

# -------------------------------
# 解压
# -------------------------------
rm -rf "openssl-${OPENSSL_VERSION}"
tar -xzf "$TARBALL"
cd "openssl-${OPENSSL_VERSION}"

# -------------------------------
# 清理旧文件
# -------------------------------
make clean || true

# -------------------------------
# 配置
# -------------------------------
CFLAGS="-O2"
CXXFLAGS="$CFLAGS"
./Configure --prefix="$PREFIX" \
    --openssldir="$PREFIX/ssl" \
    no-ssl3 \
    no-ssl3-method \
    no-zlib \
    darwin64-arm64-cc \
    enable-ec_nistp_64_gcc_128

# -------------------------------
# 编译安装
# -------------------------------
make -j$(sysctl -n hw.ncpu)
make install

# -------------------------------
# 完成提示
# -------------------------------
echo "OpenSSL $OPENSSL_VERSION installed to $PREFIX"
ls -l "$PREFIX/lib"
ls -l "$PREFIX/include"

#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------
# openssl@3 — 基于 Homebrew Formula/o/openssl@3.rb
# -------------------------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/Library/openssl}
OPENSSL_VERSION=${OPENSSL_VERSION:-3.6.2}

# -------------------------------------------------
# 下载源码
# -------------------------------------------------
TARBALL="openssl-${OPENSSL_VERSION}.tar.gz"
URL="https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/${TARBALL}"

mkdir -p build
cd build

if [ ! -f "$TARBALL" ]; then
  echo "Downloading openssl ${OPENSSL_VERSION}..."
  curl -fLo "$TARBALL" "$URL"
fi

# -------------------------------------------------
# 解压
# -------------------------------------------------
rm -rf "openssl-${OPENSSL_VERSION}"
tar -xzf "$TARBALL"
cd "openssl-${OPENSSL_VERSION}"

# -------------------------------------------------
# 配置（参照 Homebrew openssl@3 配方）
# -------------------------------------------------
# --libdir=lib : 不使用 lib64，统一用 lib
# no-ssl3 / no-ssl3-method : 禁用 SSLv3
# no-zlib : 禁用 zlib 压缩
# darwin64-arm64-cc : macOS arm64 target
# enable-ec_nistp_64_gcc_128 : 启用椭圆曲线优化
perl ./Configure \
  --prefix="$PREFIX" \
  --openssldir="$PREFIX/etc/openssl@3" \
  --libdir=lib \
  no-ssl3 \
  no-ssl3-method \
  no-zlib \
  darwin64-arm64-cc \
  enable-ec_nistp_64_gcc_128

# -------------------------------------------------
# 编译安装
# -------------------------------------------------
make -j"$(sysctl -n hw.ncpu 2>/dev/null || echo 8)"
make install MANDIR="$PREFIX/share/man" MANSUFFIX=ssl

# 创建 certs/private 目录占位
mkdir -p "$PREFIX/etc/openssl@3/certs"
mkdir -p "$PREFIX/etc/openssl@3/private"
touch "$PREFIX/etc/openssl@3/certs/.keepme"
touch "$PREFIX/etc/openssl@3/private/.keepme"

# -------------------------------------------------
# 完成提示
# -------------------------------------------------
echo "openssl ${OPENSSL_VERSION} installed to $PREFIX"
ls -l "$PREFIX/lib"

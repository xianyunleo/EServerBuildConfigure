#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------
# krb5 — 基于 Homebrew Formula/k/krb5.rb
# 依赖: openssl@3.5
# -------------------------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/Library/krb5}
KRB5_VERSION=${KRB5_VERSION:-1.22.2}
OPENSSL_PREFIX=${OPENSSL_PREFIX:-/Applications/EServer/Library/openssl@3.5}

# -------------------------------------------------
# 下载源码
# -------------------------------------------------
TARBALL="krb5-${KRB5_VERSION}.tar.gz"
URL="https://kerberos.org/dist/krb5/${KRB5_VERSION%.*}/krb5-${KRB5_VERSION}.tar.gz"

mkdir -p build
cd build

if [ ! -f "$TARBALL" ]; then
  echo "Downloading krb5 ${KRB5_VERSION}..."
  curl -fLo "$TARBALL" "$URL"
fi

# -------------------------------------------------
# 解压
# -------------------------------------------------
rm -rf "krb5-${KRB5_VERSION}"
tar -xzf "$TARBALL"
cd "krb5-${KRB5_VERSION}"

# -------------------------------------------------
# 配置（参照 Homebrew krb5 配方）
# -------------------------------------------------
# Homebrew Formula 仅传递以下 configure 参数：
#   --disable-nls
#   --disable-silent-rules
#   --without-system-verto
#   --prefix=<keg>
# OpenSSL 依赖通过 pkg-config 自动发现。
# 注意：krb5 的 configure 脚本位于 src/ 子目录。
export PKG_CONFIG_PATH="$OPENSSL_PREFIX/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
export CPPFLAGS="-I$OPENSSL_PREFIX/include"
export LDFLAGS="-L$OPENSSL_PREFIX/lib"

cd src
CFLAGS="-O2" \
CXXFLAGS="$CFLAGS" \
./configure \
  --prefix="$PREFIX" \
  --disable-nls \
  --disable-silent-rules \
  --without-system-verto

# -------------------------------------------------
# 编译安装
# -------------------------------------------------
make -j"$(sysctl -n hw.ncpu 2>/dev/null || echo 8)"
sudo make install

# -------------------------------------------------
# 完成提示
# -------------------------------------------------
echo "krb5 ${KRB5_VERSION} installed to $PREFIX"
ls -l "$PREFIX/lib"
ls -l "$PREFIX/include"
ls -l "$PREFIX/bin"

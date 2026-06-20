#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# 配置
# -------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/Library/libpq}
POSTGRESQL_VERSION=${POSTGRESQL_VERSION:-18.4}
OPENSSL_PREFIX=${OPENSSL_PREFIX:-/Applications/EServer/Library/openssl@3.5}
ICU_PREFIX=${ICU_PREFIX:-/Applications/EServer/Library/icu}
KRB5_PREFIX=${KRB5_PREFIX:-/Applications/EServer/Library/krb5}
CURL_PREFIX=${CURL_PREFIX:-/Applications/EServer/Library/curl}

# -------------------------------
# 依赖库查找路径
# -------------------------------
export PKG_CONFIG_PATH="${OPENSSL_PREFIX}/lib/pkgconfig:${ICU_PREFIX}/lib/pkgconfig:${KRB5_PREFIX}/lib/pkgconfig:${CURL_PREFIX}/lib/pkgconfig"
export PKG_CONFIG_LIBDIR="${OPENSSL_PREFIX}/lib/pkgconfig:${ICU_PREFIX}/lib/pkgconfig:${KRB5_PREFIX}/lib/pkgconfig:${CURL_PREFIX}/lib/pkgconfig"
export CPPFLAGS="-I${OPENSSL_PREFIX}/include -I${ICU_PREFIX}/include -I${KRB5_PREFIX}/include -I${CURL_PREFIX}/include"
export LDFLAGS="-L${OPENSSL_PREFIX}/lib -L${ICU_PREFIX}/lib -L${KRB5_PREFIX}/lib -L${CURL_PREFIX}/lib"

# -------------------------------
# 下载源码
# -------------------------------
TARBALL="postgresql-${POSTGRESQL_VERSION}.tar.gz"
URL="http://ftp.postgresql.org/pub/source/v${POSTGRESQL_VERSION}/$TARBALL"

mkdir -p build
cd build

if [ ! -f "$TARBALL" ]; then
  echo "Downloading PostgreSQL $POSTGRESQL_VERSION..."
  curl -LO "$URL"
fi

# -------------------------------
# 解压
# -------------------------------
rm -rf "postgresql-${POSTGRESQL_VERSION}"
tar -xzf "$TARBALL"
cd "postgresql-${POSTGRESQL_VERSION}"

# -------------------------------
# 清理旧文件
# -------------------------------
make clean || true

# -------------------------------
# 配置
# -------------------------------
CFLAGS="-O2" \
CXXFLAGS="$CFLAGS" \
./configure \
  --prefix="$PREFIX" \
  --disable-debug \
  --with-libcurl \
  --with-openssl \
  --with-gssapi

# -------------------------------
# 编译安装
# -------------------------------
make -j8
sudo make install

# -------------------------------
# 删除bin目录
# -------------------------------
if [ -d "$PREFIX/bin" ]; then
  echo "Removing bin directory as per requirements..."
  rm -rf "$PREFIX/bin"
fi

# -------------------------------
# 完成提示
# -------------------------------
echo "libpq (PostgreSQL $POSTGRESQL_VERSION) installed to $PREFIX"
ls -l "$PREFIX/lib"
ls -l "$PREFIX/include"

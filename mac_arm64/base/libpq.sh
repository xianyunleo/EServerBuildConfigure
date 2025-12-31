#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# 配置
# -------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/Library/libpq}
POSTGRESQL_VERSION=${POSTGRESQL_VERSION:-17.2}
OPENSSL_PREFIX=${OPENSSL_PREFIX:-/Applications/EServer/Library/openssl@3.5}

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
./configure --prefix="$PREFIX" \
    --with-openssl \
    --with-includes="$OPENSSL_PREFIX/include" \
    --with-libraries="$OPENSSL_PREFIX/lib" \
    --with-system-tzdata \
    --disable-debug

# -------------------------------
# 编译安装
# -------------------------------
make -j8
make install

# -------------------------------
# 删除bin目录（根据注释要求）
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

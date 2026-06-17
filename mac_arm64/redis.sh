#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# 配置
# -------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/childApp/server/redis-8.2}
REDIS_VERSION=${REDIS_VERSION:-8.2.3}

# -------------------------------
# 下载源码
# -------------------------------
TARBALL="redis-${REDIS_VERSION}.tar.gz"
URL="https://download.redis.io/releases/$TARBALL"

mkdir -p build
cd build

if [ ! -f "$TARBALL" ]; then
    echo "Downloading redis $REDIS_VERSION..."
    curl -LO "$URL"
fi

# -------------------------------
# 解压
# -------------------------------
rm -rf "redis-${REDIS_VERSION}"
tar -xzf "$TARBALL"
cd "redis-${REDIS_VERSION}"

# -------------------------------
# 清理旧文件
# -------------------------------
make clean || true

# -------------------------------
# 编译安装
# -------------------------------
make -j8 \
    BUILD_TLS=yes \
    CFLAGS="-I/Applications/EServer/Library/openssl@3.5/include" \
    LDFLAGS=-L/Applications/EServer/Library/openssl@3.5/lib

make install PREFIX="$PREFIX"

# -------------------------------
# 完成提示
# -------------------------------
echo "redis $REDIS_VERSION installed to $PREFIX"
ls -l "$PREFIX/bin"

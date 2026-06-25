#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# 配置
# -------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/childApp/server/redis-7.2}
REDIS_VERSION=${REDIS_VERSION:-7.2.14}

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
make -j"$(sysctl -n hw.ncpu 2>/dev/null || echo 8)" \
  BUILD_TLS=yes \
  CFLAGS="-I/Applications/EServer/Library/openssl@3.5/include" \
  LDFLAGS=-L/Applications/EServer/Library/openssl@3.5/lib

sudo make install PREFIX="$PREFIX"

# -------------------------------
# 完成提示
# -------------------------------
echo "redis $REDIS_VERSION installed to $PREFIX"
ls -l "$PREFIX/bin"

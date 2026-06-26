#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# 配置
# -------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/Library/argon2}
ARGON2_VERSION=${ARGON2_VERSION:-20190702}

# -------------------------------
# 下载源码
# -------------------------------
TARBALL="argon2-${ARGON2_VERSION}.tar.gz"
URL="https://github.com/P-H-C/phc-winner-argon2/archive/refs/tags/${ARGON2_VERSION}.tar.gz"

mkdir -p build
cd build

if [ ! -f "$TARBALL" ]; then
  echo "Downloading argon2 ${ARGON2_VERSION}..."
  curl -LO "$URL"
fi

# -------------------------------
# 解压
# -------------------------------
rm -rf "phc-winner-argon2-${ARGON2_VERSION}"
tar -xzf "$TARBALL"
cd "phc-winner-argon2-${ARGON2_VERSION}"

# -------------------------------
# 清理旧文件
# -------------------------------
make clean || true

# -------------------------------
# 编译 & 测试 & 安装
# -------------------------------
make \
  PREFIX="$PREFIX" \
  ARGON2_VERSION="${ARGON2_VERSION}" \
  LIBRARY_REL=lib

sudo make install \
  PREFIX="$PREFIX" \
  ARGON2_VERSION="${ARGON2_VERSION}" \
  LIBRARY_REL=lib

# -------------------------------
# 完成提示
# -------------------------------
echo "argon2 ${ARGON2_VERSION} installed to $PREFIX"
ls -l "$PREFIX/lib"
ls -l "$PREFIX/include"
ls -l "$PREFIX/bin"

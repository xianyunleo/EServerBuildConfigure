#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------
# MySQL 5.7 — 基于 Homebrew Formula/mysql.rb
# 依赖: openssl@1.1 (5.7 兼容 OpenSSL 1.1.1)
# 源码: mysql-boost-5.7.44.tar.gz (内含 boost)
# -------------------------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/childApp/server/mysql-5.7}
MYSQL_VERSION=${MYSQL_VERSION:-5.7.44}

# 统一 pkgconfig 入口（create-libs.sh 集中链接所有依赖的 .pc）
export PKG_CONFIG_PATH=${PKG_CONFIG_PATH:-/Applications/EServer/Library/lib/pkgconfig}

# -------------------------------------------------
# 下载源码（mysql-boost 包已内置 boost/ 子目录）
# -------------------------------------------------
TARBALL="mysql-boost-${MYSQL_VERSION}.tar.gz"
URL="https://downloads.mysql.com/archives/get/p/23/file/${TARBALL}"

mkdir -p build
cd build

if [ ! -f "$TARBALL" ]; then
  echo "Downloading MySQL $MYSQL_VERSION (with boost)..."
  curl -fL -o "$TARBALL" "$URL"
fi

# -------------------------------------------------
# 解压
# -------------------------------------------------
SRC_DIR="mysql-${MYSQL_VERSION}"
rm -rf "$SRC_DIR"
tar -xzf "$TARBALL"
cd "$SRC_DIR"

# -------------------------------------------------
# 清理旧构建
# -------------------------------------------------
rm -rf CMakeCache.txt CMakeFiles

# -------------------------------------------------
# 配置（参照 Homebrew mysql 配方 + macOS 兼容性补丁）
# -------------------------------------------------
# macOS 新版 Clang 默认开启 -Werror=implicit-function-declaration，
# 且 MySQL 5.7 维护者模式会启用 -Werror，需关闭以避免编译失败。
# C++ 侧使用 C++11（5.7 代码使用了 std::auto_ptr 等 C++17 已移除特性）。
export CFLAGS="-O2 -Wno-error=implicit-function-declaration -Wno-error"
export CXXFLAGS="-O2 -std=c++11 -Wno-error=deprecated-declarations -Wno-error"

ARGS=(
  -DCMAKE_INSTALL_PREFIX="$PREFIX"
  -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_OSX_DEPLOYMENT_TARGET="$MACOSX_DEPLOYMENT_TARGET"

  # —— Homebrew 配方参数 ——
  -DCOMPILATION_COMMENT=EServer
  -DDEFAULT_CHARSET=utf8
  -DDEFAULT_COLLATION=utf8_general_ci
  -DINSTALL_INCLUDEDIR=include/mysql
  -DINSTALL_PLUGINDIR=lib/plugin
  -DWITH_BOOST=boost
  -DWITH_SSL=/Applications/EServer/Library/openssl@1.1

  # —— 关闭维护者模式（避免 -Werror 导致新版 Clang 编译失败）——
  -DMYSQL_MAINTAINER_MODE=OFF

  # —— 兼容新版 CMake（5.7 的 cmake_minimum_required < 3.5，新版 CMake 已移除兼容）——
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5

  # —— 功能开关 ——
  -DENABLED_LOCAL_INFILE=ON
  -DENABLED_PROFILING=OFF
  -DWITH_SYSTEMD=OFF

  # —— 使用 bundled 第三方库，避免与系统库版本冲突 ——
  -DWITH_EDITLINE=bundled
  -DWITH_LZ4=bundled
  -DWITH_ZLIB=bundled
  -DWITH_PROTOBUF=bundled
  -DWITH_ICU=bundled

  # —— 允许在源码目录内构建 ——
  -DFORCE_INSOURCE_BUILD=ON
)

cmake "${ARGS[@]}"

# -------------------------------------------------
# 编译安装
# -------------------------------------------------
make -j"$(sysctl -n hw.ncpu 2>/dev/null || echo 8)"
sudo make install

# -------------------------------------------------
# 完成提示（server 目录按项目约定不删除任何文件）
# -------------------------------------------------
echo "MySQL $MYSQL_VERSION installed to $PREFIX"
ls -l "$PREFIX/bin"
echo ""
echo "=== mysqld --version ==="
"$PREFIX/bin/mysqld" --version 2>&1 || true
echo ""
echo "=== file architectures ==="
for f in "$PREFIX/bin/mysqld" "$PREFIX/bin/mysql"; do
  lipo -info "$f" 2>/dev/null || file "$f"
done
echo ""
echo "=== minimum macOS version ==="
otool -l "$PREFIX/bin/mysqld" | grep -A 3 LC_BUILD_VERSION
echo ""
echo "=== dependencies ==="
otool -L "$PREFIX/bin/mysqld"

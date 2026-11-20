#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------
# MySQL 5.7.44（5.7 系列最后一个 GA 版本，已 EOL）
# 参考: Homebrew Formula mysql@5.7
# 依赖: openssl@1.1 —— 5.7 不兼容 OpenSSL 3.x，必须使用 1.1.1
# 源码: mysql-boost-5.7.44.tar.gz（已内置 boost/ 子目录）
# -------------------------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/childApp/server/mysql-5.7}
MYSQL_VERSION=${MYSQL_VERSION:-5.7.44}
OPENSSL_PREFIX=${OPENSSL_PREFIX:-/Applications/EServer/Library/openssl@1.1}

# 仓库根目录（脚本位于 mac_arm64/server/），用于集中存放 cmake 日志
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# 统一 pkgconfig 入口（create-libs.sh 集中链接所有依赖的 .pc）
export PKG_CONFIG_PATH=${PKG_CONFIG_PATH:-/Applications/EServer/Library/lib/pkgconfig}

# -------------------------------------------------
# 前置检查：OpenSSL 1.1 必须显式存在
# 注意: CMake 的 IF() 会把字符串 "off" 当成 TRUE，
#       所以 -DWITH_SSL=off 并不能真正关闭 SSL，必须传真实路径。
# -------------------------------------------------
if [ ! -d "$OPENSSL_PREFIX" ]; then
  echo "ERROR: OpenSSL 1.1 not found at $OPENSSL_PREFIX"
  echo "       MySQL 5.7 does not support OpenSSL 3.x. Build openssl@1.1 first:"
  echo "       mac_arm64/base/openssl@1.1.sh"
  exit 1
fi

echo "MySQL       : $MYSQL_VERSION"
echo "PREFIX      : $PREFIX"
echo "OpenSSL     : $OPENSSL_PREFIX"
echo "DeployTarget: $MACOSX_DEPLOYMENT_TARGET"

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
# 修补内置 zlib 的 fdopen 宏冲突
# zutil.h 在 macOS 分支里写了 `#define fdopen(fd,mode) NULL`，
# 而新版 macOS SDK（Xcode 16.4+ / 26）的 _stdio.h 会无条件声明
# `FILE *fdopen(int, const char *)`，宏展开后直接编译失败：
#   _stdio.h:322: error: expected identifier or '('
# 上游 madler/zlib#1076 到 1.3.1 才修，5.7 的 bundled 1.2.13 不会更新。
# -------------------------------------------------
for zutil in extra/zlib/zlib-*/zutil.h; do
  [ -f "$zutil" ] || continue
  echo "Patching $zutil (drop fdopen macro)"
  sed -i '' -E 's|^#[[:space:]]*define[[:space:]]+fdopen\(fd,mode\)[[:space:]]+NULL.*$|/* patched out by EServer: conflicts with macOS SDK stdio.h */|' "$zutil"
  grep -n "fdopen" "$zutil" || true
done

# -------------------------------------------------
# 配置（参照 Homebrew mysql@5.7 配方 + macOS 兼容性补丁）
# -------------------------------------------------
# 新版 Clang 默认开启 -Werror=implicit-function-declaration，
# 且 5.7 的维护者模式会启用 -Werror，直接编译必然失败，故整体关闭。
# C++ 侧固定 C++11：5.7 代码仍在使用 std::auto_ptr 等 C++17 已移除特性。
# -Wno-enum-constexpr-conversion：clang 16 起把该诊断升级为错误，而 5.7 钉死
# 的 boost 1.59 在 mpl/aux_/integral_wrapper.hpp 里做 static_cast<Enum>(value-1)
# 会算出 -1（越界常量转换），不放行就编不过。
export CFLAGS="-O2 -Wno-error=implicit-function-declaration -Wno-error"
export CXXFLAGS="-O2 -std=c++11 -Wno-error=deprecated-declarations -Wno-error -Wno-enum-constexpr-conversion"

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
  -DWITH_SSL="$OPENSSL_PREFIX"

  # —— 关闭维护者模式（避免 -Werror 导致新版 Clang 编译失败）——
  -DMYSQL_MAINTAINER_MODE=OFF
  -DWITH_DEBUG=OFF

  # —— 兼容新版 CMake（5.7 的 cmake_minimum_required < 3.5，
  #    CMake 3.27+ 已移除对 < 3.5 的兼容策略）——
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5

  # —— 功能开关 ——
  -DENABLED_LOCAL_INFILE=ON
  -DENABLED_PROFILING=OFF
  -DWITH_SYSTEMD=OFF
  -DWITH_UNIT_TESTS=OFF

  # —— 使用 bundled 第三方库，避免与系统/EServer Library 版本冲突 ——
  -DWITH_EDITLINE=bundled
  -DWITH_LZ4=bundled
  -DWITH_ZLIB=bundled
  -DWITH_PROTOBUF=bundled
  -DWITH_ICU=bundled

  # —— 允许在源码目录内构建（5.7 官方推荐 in-source build）——
  -DFORCE_INSOURCE_BUILD=ON
)

set +e
cmake "${ARGS[@]}" 2>&1 | tee cmake-output.log
CMAKE_EXIT=${PIPESTATUS[0]}
set -e

# 失败时把日志留在仓库根目录的 cmake_logs/ 下，方便 CI 上传
mkdir -p "$REPO_ROOT/cmake_logs"
cp cmake-output.log "$REPO_ROOT/cmake_logs/cmake-output.log" 2>/dev/null || true

if [ "$CMAKE_EXIT" -ne 0 ]; then
  echo ""
  echo "========== CMake Error Summary =========="
  grep -i -n "cmake error\|send_error\|fatal_error\|error:" cmake-output.log || true
  echo "========================================="
  exit "$CMAKE_EXIT"
fi

# -------------------------------------------------
# 编译安装
# 日志同时落 cmake_logs/build.log；失败时用 ::error:: 注解输出错误
# 行（Actions 原始日志需登录才能下载，注解页公开可读）
# -------------------------------------------------
BUILD_LOG="$REPO_ROOT/cmake_logs/build.log"
set +e
make -j"$(sysctl -n hw.ncpu 2>/dev/null || echo 8)" 2>&1 | tee -a "$BUILD_LOG"
MAKE_EXIT=${PIPESTATUS[0]}
set -e

if [ "$MAKE_EXIT" -ne 0 ]; then
  echo ""
  echo "========== make failed (exit $MAKE_EXIT) =========="
  if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
    # 只匹配 clang 诊断行 `path:line:col: error:`，避免命中源码里的 "error:" 字符串
    first=$(grep -n -a -m1 -E ":[0-9]+:[0-9]+: (fatal )?error:" "$BUILD_LOG" | cut -d: -f1 || true)
    if [ -n "$first" ]; then
      echo "::error title=make failed (exit $MAKE_EXIT, first error line $first):: $(sed -n "${first},$(( first + 5 ))p" "$BUILD_LOG" | tr -d '\r' | tr '\n' '|' | cut -c1-1400)"
    else
      echo "::error title=make failed (exit $MAKE_EXIT):: $(tail -n 20 "$BUILD_LOG" | tr -d '\r' | tr '\n' '|' | cut -c1-1400)"
    fi
  fi
  tail -n 60 "$BUILD_LOG" || true
  exit "$MAKE_EXIT"
fi

sudo make install

# -------------------------------------------------
# 完成提示（server 类目录按项目约定不删除任何文件）
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

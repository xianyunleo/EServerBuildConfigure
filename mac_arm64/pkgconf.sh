#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------
# pkgconf — 基于 Homebrew Formula/p/pkgconf.rb
# 构建工具，为 libngtcp2/curl 的 configure 提供 pkg-config 支持
# -------------------------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/Library/pkgconf}
PKGCONF_VERSION=${PKGCONF_VERSION:-2.5.1}
SDK_PATH=${SDK_PATH:-$(xcrun --show-sdk-path 2>/dev/null || echo "")}

# -------------------------------------------------
# 下载源码
# -------------------------------------------------
TARBALL="pkgconf-${PKGCONF_VERSION}.tar.xz"
URL="https://distfiles.ariadne.space/pkgconf/${TARBALL}"

mkdir -p build
cd build

if [ ! -f "$TARBALL" ]; then
  echo "Downloading pkgconf ${PKGCONF_VERSION}..."
  curl -fLo "$TARBALL" "$URL"
fi

# -------------------------------------------------
# 解压
# -------------------------------------------------
rm -rf "pkgconf-${PKGCONF_VERSION}"
tar -xJf "$TARBALL"
cd "pkgconf-${PKGCONF_VERSION}"

# -------------------------------------------------
# 配置（参照 Homebrew pkgconf 配方）
# -------------------------------------------------
ARGS=(
  --prefix="$PREFIX"
  --disable-silent-rules
)

# macOS: 指定系统 include/lib 目录
if [ -n "$SDK_PATH" ]; then
  ARGS+=(--with-system-includedir="${SDK_PATH}/usr/include")
fi
ARGS+=(--with-system-libdir=/usr/lib)

CFLAGS="-O2" \
CXXFLAGS="$CFLAGS" \
./configure "${ARGS[@]}"

# -------------------------------------------------
# 编译安装
# -------------------------------------------------
make -j"$(sysctl -n hw.ncpu 2>/dev/null || echo 8)"
make install

# 创建 pkg-config 软链接（兼容性）
ln -sf "$PREFIX/bin/pkgconf" "$PREFIX/bin/pkg-config"
ln -sf "$PREFIX/share/man/man1/pkgconf.1" "$PREFIX/share/man/man1/pkg-config.1" 2>/dev/null || true

# -------------------------------------------------
# 完成提示
# -------------------------------------------------
echo "pkgconf ${PKGCONF_VERSION} installed to $PREFIX"
ls -l "$PREFIX/bin"

#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# 配置
# -------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/childApp/php/php-7.4}
PHP_VERSION=${PHP_VERSION:-7.4.33}

# build.log 固定落仓库根目录（脚本启动时的 cwd），不受后续 cd 影响
BUILD_LOG="$(pwd)/build.log"
: > "$BUILD_LOG"   # 预创建/清空

# -------------------------------
# 下载源码
# -------------------------------
TARBALL="php-src-backports-7.4.33.tar.gz"
URL="https://raw.githubusercontent.com/xianyunleo/EServerBuildConfigure/master/php-src-backports/$TARBALL"

mkdir -p build
cd build

if [ ! -f "$TARBALL" ]; then
  echo "Downloading PHP $PHP_VERSION..."
  curl -LO "$URL"
fi

# -------------------------------
# 解压
# -------------------------------
rm -rf "php-${PHP_VERSION}"
rm -rf "php-src-backports-7.4.33"
tar -xzf "$TARBALL"
SRC_DIR=$(tar -tzf "$TARBALL" | head -1 | cut -d/ -f1)
echo "Source directory: $SRC_DIR" | tee -a "$BUILD_LOG"
cd "$SRC_DIR"
echo "=== ls -la ===" >> "$BUILD_LOG"
ls -la >> "$BUILD_LOG"

# -------------------------------
# 清理旧文件 & 生成 configure
# -------------------------------
make clean 2>/dev/null || true
if [ ! -f configure ]; then
  echo "configure not found, running ./buildconf..." | tee -a "$BUILD_LOG"
  ./buildconf --force 2>&1 | tee -a "$BUILD_LOG"
fi

# -------------------------------
# 补丁: cURL 需要 long 类型字面量
# -------------------------------
echo "=== curl sed patch ===" >> "$BUILD_LOG"
sed -i.bak -E 's/CURLOPT_VERBOSE,\s+0/CURLOPT_VERBOSE, 0L/' ext/curl/interface.c

# -------------------------------
# 配置
# 捕获 configure 和 make 的全部输出到 build.log
# -------------------------------

# PHP 7.4 的 K&R 风格源码不兼容 C23，强制使用 C17
export CFLAGS="${CFLAGS:+$CFLAGS }-std=gnu17"

# Xcode 15.3+ (clang build >= 1500) 兼容性修复
CLANG_BUILD=$(clang --version 2>/dev/null | grep -oE 'clang-[0-9]+' | head -1 | sed 's/clang-//')
if [ -n "$CLANG_BUILD" ] && [ "$CLANG_BUILD" -ge 1500 ]; then
  echo "Detected clang build $CLANG_BUILD >= 1500, applying Xcode 15.3 workarounds..." | tee -a "$BUILD_LOG"
  export CFLAGS="${CFLAGS:+$CFLAGS }-Wno-incompatible-function-pointer-types"
  export LDFLAGS="${LDFLAGS:+$LDFLAGS }-lresolv"
fi

# gcc 编译器兼容（macOS 上使用 gcc 时）
if [ "$(uname)" = "Darwin" ] && [ "${CC:-}" = "gcc" ]; then
  export CFLAGS="${CFLAGS:+$CFLAGS }-Wno-incompatible-pointer-types"
fi

export LIBS="${LIBS:+$LIBS }-lresolv"
export PKG_CONFIG_PATH=/Applications/EServer/Library/openssl@3.5/lib/pkgconfig:/Applications/EServer/Library/curl/lib/pkgconfig:/Applications/EServer/Library/libgd/lib/pkgconfig:/Applications/EServer/Library/oniguruma/lib/pkgconfig:/Applications/EServer/Library/zlib/lib/pkgconfig:/Applications/EServer/Library/libxml2/lib/pkgconfig:/Applications/EServer/Library/libzip/lib/pkgconfig:/Applications/EServer/Library/icu/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}

echo "=== configure start ===" >> "$BUILD_LOG"
./configure --prefix="$PREFIX" \
  --with-config-file-path="$PREFIX/etc" \
  --enable-bcmath \
  --enable-calendar \
  --enable-exif \
  --enable-ftp \
  --enable-fpm \
  --enable-gd=shared \
  --with-external-gd \
  --enable-mbstring \
  --enable-mbregex \
  --enable-opcache \
  --enable-soap \
  --enable-sockets \
  --enable-intl \
  --enable-pcntl \
  --with-bz2=/Applications/EServer/Library/bzip2 \
  --with-curl=shared \
  --with-gmp=/Applications/EServer/Library/gmp \
  --with-iconv=/Applications/EServer/Library/libiconv \
  --with-mysqli \
  --with-openssl=shared \
  --with-pdo-mysql \
  --with-pgsql=/Applications/EServer/Library/libpq \
  --with-pdo-pgsql=/Applications/EServer/Library/libpq \
  --with-pdo-sqlite \
  --with-sqlite3 \
  --with-libxml \
  --with-zip \
  --with-zlib \
  2>&1 | tee -a "$BUILD_LOG"
echo "=== configure end (exit: ${PIPESTATUS[0]}) ===" >> "$BUILD_LOG"

# -------------------------------
# 编译安装
# -------------------------------
echo "=== make start ===" >> "$BUILD_LOG"
make -j"$(sysctl -n hw.ncpu 2>/dev/null || echo 8)" V=1 2>&1 | tee -a "$BUILD_LOG"
echo "=== make end (exit: ${PIPESTATUS[0]}) ===" >> "$BUILD_LOG"

echo "=== make install start ===" >> "$BUILD_LOG"
sudo make install 2>&1 | tee -a "$BUILD_LOG"
echo "=== make install end (exit: ${PIPESTATUS[0]}) ===" >> "$BUILD_LOG"

sudo cp ./php.ini-development /Applications/EServer/childApp/php/php-7.4/etc/php.ini-development
sudo cp ./php.ini-production /Applications/EServer/childApp/php/php-7.4/etc/php.ini-production

# -------------------------------
# 完成提示
# -------------------------------
echo "PHP $PHP_VERSION installed to $PREFIX"
ls -l "$PREFIX/bin"
"$PREFIX/bin/php" -v

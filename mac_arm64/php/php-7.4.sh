#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# 配置
# -------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/childApp/php/php-7.4}
PHP_VERSION=${PHP_VERSION:-7.4.33}

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
echo "Source directory: $SRC_DIR"
cd "$SRC_DIR"
ls -la

# -------------------------------
# 配置环境变量
# -------------------------------

# PHP 7.4 的 K&R 风格源码不兼容 C23，强制使用 C17
export CFLAGS="${CFLAGS:+$CFLAGS }-std=gnu17"

# Xcode 15.3+ (clang build >= 1500) 兼容性修复
CLANG_BUILD=$(clang --version 2>/dev/null | grep -oE 'clang-[0-9]+' | head -1 | sed 's/clang-//')
if [ -n "$CLANG_BUILD" ] && [ "$CLANG_BUILD" -ge 1500 ]; then
  echo "Detected clang build $CLANG_BUILD >= 1500, applying Xcode 15.3 workarounds..."
  export CFLAGS="${CFLAGS:+$CFLAGS }-Wno-incompatible-function-pointer-types"
  export LDFLAGS="${LDFLAGS:+$LDFLAGS }-lresolv"
fi

# gcc 编译器兼容（macOS 上使用 gcc 时）
if [ "$(uname)" = "Darwin" ] && [ "${CC:-}" = "gcc" ]; then
  export CFLAGS="${CFLAGS:+$CFLAGS }-Wno-incompatible-pointer-types"
fi

# ICU 75+ 需要 C++17
export ICU_CXXFLAGS="-std=c++17"

# macOS: 确保 Mach-O header 有足够空间用于 rpath 重写
if [ "$(uname)" = "Darwin" ]; then
  export LDFLAGS="${LDFLAGS:+$LDFLAGS }-Wl,-headerpad_max_install_names"
fi

export LIBS="${LIBS:+$LIBS }-lresolv"

# -------------------------------
# 清理旧文件 & 生成 configure
# -------------------------------
make clean 2>/dev/null || true
if [ ! -f configure ]; then
  echo "configure not found, running ./buildconf..."
  ./buildconf --force
fi

# -------------------------------
# 补丁: cURL 需要 long 类型字面量
# -------------------------------
sed -i.bak -E 's/CURLOPT_VERBOSE,\s+0/CURLOPT_VERBOSE, 0L/' ext/curl/interface.c

# -------------------------------
# 配置
# -------------------------------

PKG_CONFIG_PATH=/Applications/EServer/Library/lib/pkgconfig \
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
  --with-openssl-argon2 \
  --with-pdo-mysql \
  --with-pgsql=/Applications/EServer/Library/libpq \
  --with-pdo-pgsql=/Applications/EServer/Library/libpq \
  --with-pdo-sqlite \
  --with-sqlite3 \
  --with-libxml \
  --with-zip \
  --with-zlib

# -------------------------------
# 编译安装
# -------------------------------
make -j"$(sysctl -n hw.ncpu 2>/dev/null || echo 8)"
sudo make install

sudo cp ./php.ini-development /Applications/EServer/childApp/php/php-7.4/etc/php.ini-development
sudo cp ./php.ini-production /Applications/EServer/childApp/php/php-7.4/etc/php.ini-production

# -------------------------------
# 完成提示
# -------------------------------
echo "PHP $PHP_VERSION installed to $PREFIX"
ls -l "$PREFIX/bin"
"$PREFIX/bin/php" -v


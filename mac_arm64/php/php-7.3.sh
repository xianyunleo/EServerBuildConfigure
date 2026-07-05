#!/usr/bin/env bash
set -euo pipefail
# -------------------------------
# 配置
# -------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/childApp/php/php-7.3}
PHP_VERSION=${PHP_VERSION:-7.3.33}

# -------------------------------
# 下载源码
# -------------------------------
TARBALL="php-${PHP_VERSION}.tar.gz"
URL="https://www.php.net/distributions/$TARBALL"

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
tar -xzf "$TARBALL"
cd "php-${PHP_VERSION}"

# -------------------------------
# 清理旧文件
# -------------------------------
make clean || true

# 低版本 PHP 的 K&R 风格源码不兼容 C23，强制使用 C17 + 抑制隐式函数声明错误
export CFLAGS="${CFLAGS:+$CFLAGS }-std=gnu17 -Wno-implicit-function-declaration"

# Xcode 15.3+ (clang build >= 1500) 兼容性修复
CLANG_BUILD=$(clang --version 2>/dev/null | grep -oE 'clang-[0-9]+' | head -1 | sed 's/clang-//')
if [ -n "$CLANG_BUILD" ] && [ "$CLANG_BUILD" -ge 1500 ]; then
  echo "Detected clang build $CLANG_BUILD >= 1500, applying Xcode 15.3 workarounds..."
  export CFLAGS="${CFLAGS:+$CFLAGS }-Wno-incompatible-function-pointer-types"
  export LDFLAGS="${LDFLAGS:+$LDFLAGS }-lresolv"
  # readdir_r 在 macOS 新版 SDK 中已废弃，2 参数形式已移除，需替换为 3 参数形式
  sed -i '' 's/readdir_r(dirp, entry)/readdir_r(dirp, entry, result)/g' main/reentrancy.c
fi

# ICU 75+ 需要 C++17
export ICU_CXXFLAGS="-std=c++17"
export LIBS="${LIBS:+$LIBS }-lresolv"
export CXXFLAGS="${CXXFLAGS:+$CXXFLAGS} -stdlib=libc++"
export LDFLAGS="$LDFLAGS -stdlib=libc++"

# -------------------------------
# 补丁
# -------------------------------
echo "Applying patches..."
patch -p1 < ../../patch/php/0001-Add-support-for-ICU-70.1-PHP7.3.patch
patch -p1 < ../../patch/php/0002-Add-minimal-OpenSSL-3.0-patch-PHP7.3.patch
patch -p1 < ../../patch/php/0003-Fix-bug-79589-ssl3_read_n-unexpected-eof-while-reading-PHP7.3.patch
patch -p1 < ../../patch/php/0006-Use-ITIMER_REAL-for-timeout-handling-PHP-7.3.patch
patch -p1 < ../../patch/php/0010-Fix-GH-16168-Fix-inline-assembly-labels-to-not-crash-PHP7.3.patch


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
--enable-mbstring \
--enable-mbregex \
--enable-soap \
--enable-sockets \
--enable-intl \
--enable-pcntl \
--enable-zip \
--with-bz2=/Applications/EServer/Library/bzip2 \
--with-iconv=/Applications/EServer/Library/libiconv \
--with-mysqli \
--with-pdo-mysql \
--with-pgsql=/Applications/EServer/Library/libpq \
--with-pdo-pgsql=/Applications/EServer/Library/libpq \
--with-pdo-sqlite \
--with-sqlite3 \
--with-jpeg-dir=/Applications/EServer/Library/libjpeg-turbo \
--with-png-dir=/Applications/EServer/Library/libpng \
--with-webp-dir=/Applications/EServer/Library/libwebp \
--with-freetype-dir=/Applications/EServer/Library/freetype \
--with-libxml-dir=/Applications/EServer/Library/libxml2@2.11 \
--with-zlib-dir=/Applications/EServer/Library/zlib

# -------------------------------
# 屏蔽XPM，https://bugs.php.net/bug.php?id=66204
# -------------------------------
echo "Custom: disable xpm"
sed -i '' '/HAVE_GD_XPM/d' main/php_config.h

# -------------------------------
# 编译安装
# -------------------------------
make
sudo make install

sudo cp ./php.ini-development /Applications/EServer/childApp/php/php-7.3/etc/php.ini-development
sudo cp ./php.ini-production /Applications/EServer/childApp/php/php-7.3/etc/php.ini-production

# -------------------------------
# 完成提示
# -------------------------------
echo "PHP $PHP_VERSION installed to $PREFIX"
ls -l "$PREFIX/bin"
"$PREFIX/bin/php" -v

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

# -------------------------------
# 下载源码
# -------------------------------
TARBALL="php-src-backports-7.3.33.tar.gz"
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
rm -rf "php-src-backports-7.3.33"
tar -xzf "$TARBALL"
SRC_DIR=$(tar -tzf "$TARBALL" | head -1 | cut -d/ -f1)
echo "Source directory: $SRC_DIR"
cd "$SRC_DIR"
ls -la

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
export CXXFLAGS="$CXXFLAGS -stdlib=libc++"
export LDFLAGS="$LDFLAGS -stdlib=libc++"

# -------------------------------
# 清理旧文件 & 生成 configure
# -------------------------------
make clean 2>/dev/null || true
if [ ! -f configure ]; then
  echo "configure not found, running ./buildconf..."
  ./buildconf --force
fi

# -------------------------------
# 补丁
# -------------------------------


# -------------------------------
# 配置
# -------------------------------
LIBXPM_PREFIX=$(brew --prefix libxpm)
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
--enable-opcache \
--enable-opcache-file \
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
--with-libxml-dir=/Applications/EServer/Library/libxml2 \
--with-zlib-dir=/Applications/EServer/Library/zlib

# -------------------------------
# 屏蔽XPM，https://bugs.php.net/bug.php?id=66204
# -------------------------------
#echo "Custom: disable xpm"
#sed -i '' '/HAVE_GD_XPM/d' main/php_config.h

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

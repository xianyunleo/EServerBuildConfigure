#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# 配置
# -------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/childApp/php/php-7.0}
PHP_VERSION=${PHP_VERSION:-7.0.33}

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

# PHP 7.0 的 configure 用 K&R 老写法 main() {...} 探测 sprintf 是否损坏，
# Xcode 26 的 clang 对隐式 int 直接报错，try_run 必然失败 → 误判 ZEND_BROKEN_SPRINTF=1，
# 于是 php_config.h 里会生成 int zend_sprintf(...) 声明；而 7.0 的这个头还没有
# include guard（7.2+ 才加上），C++ 单元里被 extern "C" 内外各包含一次就报
# "declaration of 'zend_sprintf' has a different language linkage"。
# macOS 的 sprintf 本身正常，直接把 configure 的缓存值钉成 no。
export ac_cv_broken_sprintf=no
# ICU 75+ 需要 C++17。PHP 7.0 的 PHP_SETUP_ICU 只把 icu-config 的
# --cppflags-searchpath 结果当成 ICU_INCS（没有 ICU_CXXFLAGS 这一路），
# 所以 -std=c++17 只能经 CXXFLAGS 进到 ext/intl 的 .cpp 编译行。
# ICU 68+ 公共头文件默认不再定义 TRUE/FALSE，而 PHP 7.0 的 ext/intl 仍在用。
# 启用 ICU 官方过渡开关恢复这两个宏（PHP 7.3+ 已改用 1/0，无需此开关）。
export CFLAGS="${CFLAGS:+$CFLAGS }-DU_DEFINE_FALSE_AND_TRUE=1"
export LIBS="${LIBS:+$LIBS }-lresolv"
export CXXFLAGS="${CXXFLAGS:+$CXXFLAGS} -std=c++17 -DU_DEFINE_FALSE_AND_TRUE=1"
export LDFLAGS="${LDFLAGS:+$LDFLAGS }-Wl,-headerpad_max_install_names"

# -------------------------------
# 补丁（官方源码在 arm64 macOS + 高版本 ICU/OpenSSL 下编译必需）
# -------------------------------
echo "Applying patches..."
patch -p1 < ../../patch/php/0001-Add-support-for-ICU-70.1-PHP7.0-7.2.patch
patch -p1 < ../../patch/php/0002-Add-minimal-OpenSSL-3.0-patch-PHP7.0.patch
patch -p1 < ../../patch/php/0003-Fix-bug-79589-ssl3_read_n-unexpected-eof-while-reading-PHP7.0.patch
patch -p1 < ../../patch/php/0006-Use-ITIMER_REAL-for-timeout-handling-PHP-7.0.patch
patch -p1 < ../../patch/php/0008-Remove-use-of-register-keywork-in-headers-PHP-7.0.patch


# PHP 7.0 的 PHP_SETUP_ICU 只认 icu-config（7.1+ 才有 pkg-config 分支），
# 必须显式给 --with-icu-dir，否则会去 PATH 里找 icu-config 而失败。
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
--enable-soap \
--enable-sockets \
--enable-intl \
--enable-pcntl \
--enable-zip \
--with-icu-dir=/Applications/EServer/Library/icu \
--with-bz2=/Applications/EServer/Library/bzip2 \
--with-curl=shared,/Applications/EServer/Library/curl \
--with-mysqli \
--with-gd=shared \
--with-gmp=/Applications/EServer/Library/gmp \
--with-iconv=/Applications/EServer/Library/libiconv \
--with-openssl=shared,/Applications/EServer/Library/openssl@3.5 \
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
# 修复 opcache shared module 链接：MACOSX_DEPLOYMENT_TARGET=11.0 不匹配
# libtool.m4 的 darwin case 分支（10.*），导致 _lt_dar_allow_undefined 为空，
# opcache.so 链接时缺少 -undefined dynamic_lookup，无法解析主程序的
# _zend_sort / _OnUpdateBool 等符号。此处对生成的 libtool 追加该 flag。
# -------------------------------
LIBTOOL_FILE="$(pwd)/libtool"
if [ -f "$LIBTOOL_FILE" ]; then
  sed -i '' 's/^allow_undefined_flag=""$/allow_undefined_flag=" -undefined dynamic_lookup"/' "$LIBTOOL_FILE"
  echo "Patched libtool allow_undefined_flag:"
  grep -n '^allow_undefined_flag=' "$LIBTOOL_FILE" || true
fi

# -------------------------------
# 屏蔽XPM，https://bugs.php.net/bug.php?id=66204
# -------------------------------
#echo "Custom: disable xpm"
#sed -i '' '/HAVE_GD_XPM/d' main/php_config.h

# -------------------------------
# 编译安装
# -------------------------------
MAKE_LOG="$(pwd)/make.log"
make -j"$(sysctl -n hw.ncpu 2>/dev/null || echo 8)" 2>&1 | tee "$MAKE_LOG"
sudo make install

sudo cp ./php.ini-development "$PREFIX/etc/php.ini-development"
sudo cp ./php.ini-production "$PREFIX/etc/php.ini-production"

# -------------------------------
# 完成提示
# -------------------------------
echo "PHP $PHP_VERSION installed to $PREFIX"
ls -l "$PREFIX/bin"
"$PREFIX/bin/php" -v

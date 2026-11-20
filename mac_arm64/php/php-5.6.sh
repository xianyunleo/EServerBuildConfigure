#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# 配置
# -------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/childApp/php/php-5.6}
PHP_VERSION=${PHP_VERSION:-5.6.40}

# 官方 php-5.6.40 的 ext/openssl 只支持到 OpenSSL 1.0.2：它直接读 dsa->p /
# dsa->priv_key 这类结构体字段，而 OpenSSL 1.1.0 起 DSA/DH/RSA 全部 opaque 化，
# 编译必然报 "incomplete definition of type 'DSA'"。所以这里不用 php.net 官方
# tarball，改用 shivammathur/php-src-backports 的 security-backports + openssl11
# 线源码（main/php_version.h 仍是 5.6.40）。
# 该树已内置全部所需 backport，无需再打任何 patch：
#   OpenSSL 1.1/3.x/4.x accessor 改造、ICU 70 适配、bug 79589 (TLS EOF)、
#   aarch64 ZEND_SIGNED_MULTIPLY_LONG、pthreads 交叉编译检测、ITIMER_REAL、
#   头文件 register 关键字移除、LDAP 默认 host 修复。
# 参考 shivammathur/homebrew-php 的 Formula/php@5.6.rb。
SOURCE_COMMIT=${SOURCE_COMMIT:-048228913b6eeda72b784c59c43a7bfe8eb05f34}
SRC_NAME="php-src-backports-${SOURCE_COMMIT}"
TARBALL="${SRC_NAME}.tar.gz"
URL="https://github.com/shivammathur/php-src-backports/archive/${SOURCE_COMMIT}.tar.gz"

# -------------------------------
# 下载源码
# -------------------------------
mkdir -p build
cd build

if [ ! -f "$TARBALL" ]; then
  echo "Downloading php-src-backports @ $SOURCE_COMMIT..."
  curl -fL -o "$TARBALL" "$URL"
fi

# -------------------------------
# 解压
# -------------------------------
rm -rf "$SRC_NAME"
tar -xzf "$TARBALL"
cd "$SRC_NAME"

# -------------------------------
# 编译环境（对齐 homebrew-php php@5.6 的 ENV 设置）
# -------------------------------
# 5.6 的 K&R 风格源码在 C23 下编译不过，锁到 gnu99；
# Xcode 15.3+ (clang build >= 1500) 起隐式 int / 整数转指针 / 函数指针不兼容
# 都直接报错，必须降级为警告。
export CFLAGS="${CFLAGS:+$CFLAGS }-std=gnu99 -Wno-implicit-function-declaration"
CLANG_BUILD=$(clang --version 2>/dev/null | grep -oE 'clang-[0-9]+' | head -1 | sed 's/clang-//')
if [ -n "$CLANG_BUILD" ] && [ "$CLANG_BUILD" -ge 1500 ]; then
  echo "Detected clang build $CLANG_BUILD >= 1500, applying Xcode 15.3 workarounds..."
  export CFLAGS="${CFLAGS:+$CFLAGS }-Wno-incompatible-function-pointer-types -Wno-implicit-int -Wno-int-conversion"
fi
# readdir_r 在 macOS 新版 SDK 中已废弃，2 参数形式已移除，需替换为 3 参数形式
# （只有 configure 误判成 HAVE_OLD_READDIR_R 时才会走到这段，替换了也无害）
sed -i '' 's/readdir_r(dirp, entry)/readdir_r(dirp, entry, result)/g' main/reentrancy.c

# 5.6 的 configure 用 K&R 老写法 main() {...} 探测 sprintf 是否损坏，
# Xcode 26 的 clang 对隐式 int 直接报错，try_run 必然失败 → 误判 ZEND_BROKEN_SPRINTF=1，
# 于是 php_config.h 里会生成 int zend_sprintf(...) 声明；而这些版本的 php_config.h
# 还没有 include guard，C++ 单元里被 extern "C" 内外各包含一次就报
# "declaration of 'zend_sprintf' has a different language linkage"。
# macOS 的 sprintf 本身正常，直接把 configure 的缓存值钉成 no。
export ac_cv_broken_sprintf=no
# ICU 68+ 公共头文件默认不再定义 TRUE/FALSE，而 ext/intl 仍在用；
# 启用 ICU 官方过渡开关恢复这两个宏（PHP 7.3+ 已改用 1/0，无需此开关）。
export CFLAGS="${CFLAGS:+$CFLAGS }-DU_DEFINE_FALSE_AND_TRUE=1"
export CXXFLAGS="${CXXFLAGS:+$CXXFLAGS} -DU_DEFINE_FALSE_AND_TRUE=1"
# U_USING_ICU_NAMESPACE：ICU 的 uversion.h 现在恒默认 0，不再自动 `using namespace icu_XX`，
# ext/intl 里裸用 UnicodeString 就报 unknown type name。5.6 的 PHP_SETUP_ICU 只有
# icu-config 一条路、从不设 ICU_CXXFLAGS，所以必须手工补（放 CPPFLAGS，C/C++ 都覆盖）。
export CPPFLAGS="${CPPFLAGS:+$CPPFLAGS }-DU_USING_ICU_NAMESPACE=1"
# ICU 75+ 需要 C++17：5.6 没有 ICU_CXXFLAGS 这一路，只能经 CXXFLAGS/CXX 进 .cpp 编译行。
export CXXFLAGS="${CXXFLAGS:+$CXXFLAGS} -std=c++17"
export LIBS="${LIBS:+$LIBS }-lresolv"
export LDFLAGS="${LDFLAGS:+$LDFLAGS }-Wl,-headerpad_max_install_names"

# -------------------------------
# 生成 configure
# -------------------------------
# 这是 git 归档源码，没有预生成的 configure，必须跑 buildconf。
echo "Running buildconf..."
./buildconf --force

# -------------------------------
# 配置
# -------------------------------
# PHP 5.6 的 PHP_SETUP_ICU 只认 icu-config（7.1+ 才有 pkg-config 分支），
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
--enable-mysqlnd \
--enable-opcache \
--enable-soap \
--enable-sockets \
--enable-intl \
--enable-pcntl \
--enable-zip \
--with-icu-dir=/Applications/EServer/Library/icu \
--with-bz2=/Applications/EServer/Library/bzip2 \
--with-curl=shared,/Applications/EServer/Library/curl \
--with-mysql=mysqlnd \
--with-mysqli=mysqlnd \
--with-pdo-mysql=mysqlnd \
--with-gd=shared \
--with-gmp=/Applications/EServer/Library/gmp \
--with-iconv=/Applications/EServer/Library/libiconv \
--with-openssl=shared,/Applications/EServer/Library/openssl@3.5 \
--with-pgsql=/Applications/EServer/Library/libpq \
--with-pdo-pgsql=/Applications/EServer/Library/libpq \
--with-pdo-sqlite \
--with-sqlite3 \
--with-jpeg-dir=/Applications/EServer/Library/libjpeg-turbo \
--with-png-dir=/Applications/EServer/Library/libpng \
--with-freetype-dir=/Applications/EServer/Library/freetype \
--with-libxml-dir=/Applications/EServer/Library/libxml2@2.11 \
--with-pic \
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

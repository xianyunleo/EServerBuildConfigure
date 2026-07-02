#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# 配置
# -------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/childApp/php/php-7.3}
PHP_VERSION=${PHP_VERSION:-7.3.33}

# build.log 固定落仓库根目录（脚本启动时的 cwd），不受后续 cd 影响
BUILD_LOG="$(pwd)/build.log"
: > "$BUILD_LOG"   # 预创建/清空

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
# 配置
# 捕获 configure 和 make 的全部输出到 build.log
# -------------------------------

echo "=== configure start ===" >> "$BUILD_LOG"
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
--with-bz2=/Applications/EServer/Library/bzip2 \
--with-curl=shared,/Applications/EServer/Library/curl \
--with-gd=shared \
--with-gmp=/Applications/EServer/Library/gmp \
--with-iconv=/Applications/EServer/Library/libiconv \
--with-openssl=shared,/Applications/EServer/Library/openssl@3.5 \
--with-password-argon2=/Applications/EServer/Library/argon2 \
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
--with-zlib-dir=/Applications/EServer/Library/zlib \
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

sudo cp ./php.ini-development /Applications/EServer/childApp/php/php-7.3/etc/php.ini-development
sudo cp ./php.ini-production /Applications/EServer/childApp/php/php-7.3/etc/php.ini-production

# -------------------------------
# 完成提示
# -------------------------------
echo "PHP $PHP_VERSION installed to $PREFIX"
ls -l "$PREFIX/bin"
"$PREFIX/bin/php" -v

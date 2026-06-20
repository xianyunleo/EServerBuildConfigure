#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# 配置
# -------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/childApp/php/php-7.1}
PHP_VERSION=${PHP_VERSION:-7.1.33}

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

# -------------------------------
# 配置
# -------------------------------
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
  --enable-opcache \
  --enable-zip \
  --with-bz2=/Applications/EServer/Library/bzip2 \
  --with-curl=/Applications/EServer/Library/curl \
  --with-freetype-dir=/Applications/EServer/Library/freetype \
  --with-gd \
  --with-gmp=/Applications/EServer/Library/gmp \
  --with-openssl=/Applications/EServer/Library/openssl@1.1 \
  --with-iconv=/Applications/EServer/Library/libiconv \
  --with-mysqli \
  --with-pdo-mysql \
  --with-pgsql=/Applications/EServer/Library/libpq \
  --with-pdo-pgsql=/Applications/EServer/Library/libpq \
  --with-pdo-sqlite \
  --with-sqlite3 \
  --with-libxml-dir=/Applications/EServer/Library/libxml2 \
  --with-jpeg-dir=/Applications/EServer/Library/jpeg \
  --with-png-dir=/Applications/EServer/Library/libpng \
  --with-zlib-dir=/Applications/EServer/Library/zlib \
  CFLAGS="-Wno-implicit-function-declaration" \
  PKG_CONFIG_PATH=/Applications/EServer/Library/freetype/lib/pkgconfig

# -------------------------------
# 编译安装
# -------------------------------
make -j8
make install

# -------------------------------
# 删除 share 目录（若存在）
# -------------------------------
if [ -d "$PREFIX/share" ]; then
  echo "Removing share directory..."
  rm -rf "$PREFIX/share"
fi


# -------------------------------
# 完成提示
# -------------------------------
echo "PHP $PHP_VERSION installed to $PREFIX"
ls -l "$PREFIX/bin"
"$PREFIX/bin/php" -v

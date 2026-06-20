#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# 配置
# -------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/childApp/php/php-8.4}
PHP_VERSION=${PHP_VERSION:-8.4.15}

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
  --enable-gd=shared \
  --enable-mbstring \
  --enable-mbregex \
  --enable-opcache \
  --enable-soap \
  --enable-sockets \
  --with-bz2=/Applications/EServer/Library/bzip2 \
  --with-curl=shared \
  --with-freetype \
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
  --with-jpeg \
  --with-zip \
  --with-zlib \
  PKG_CONFIG_PATH=/Applications/EServer/Library/openssl@3.5/lib/pkgconfig:/Applications/EServer/Library/curl/lib/pkgconfig:/Applications/EServer/Library/libpng/lib/pkgconfig:/Applications/EServer/Library/jpeg/lib/pkgconfig:/Applications/EServer/Library/oniguruma/lib/pkgconfig:/Applications/EServer/Library/zlib/lib/pkgconfig:/Applications/EServer/Library/libxml2/lib/pkgconfig:/Applications/EServer/Library/libzip/lib/pkgconfig:/Applications/EServer/Library/freetype/lib/pkgconfig

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

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

export LIBS="${LIBS:+$LIBS }-lresolv"
export PKG_CONFIG_PATH=/Applications/EServer/Library/openssl@3.5/lib/pkgconfig:/Applications/EServer/Library/curl/lib/pkgconfig:/Applications/EServer/Library/libgd/lib/pkgconfig:/Applications/EServer/Library/oniguruma/lib/pkgconfig:/Applications/EServer/Library/zlib/lib/pkgconfig:/Applications/EServer/Library/libxml2/lib/pkgconfig:/Applications/EServer/Library/libzip/lib/pkgconfig:/Applications/EServer/Library/icu/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}

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
  --with-zlib

# -------------------------------
# 编译安装
# 使用 V=1 tee build.log 捕捉 make 输出
# -------------------------------
make -j"$(sysctl -n hw.ncpu 2>/dev/null || echo 8)" V=1 2>&1 | tee "$BUILD_LOG"
sudo make install

sudo cp ./php.ini-development /Applications/EServer/childApp/php/php-7.4/etc/php.ini-development
sudo cp ./php.ini-production /Applications/EServer/childApp/php/php-7.4/etc/php.ini-production

# -------------------------------
# 完成提示
# -------------------------------
echo "PHP $PHP_VERSION installed to $PREFIX"
ls -l "$PREFIX/bin"
"$PREFIX/bin/php" -v

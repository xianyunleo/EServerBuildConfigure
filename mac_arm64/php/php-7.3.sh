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

# -------------------------------
# 配置
# -------------------------------
if ! PKG_CONFIG_PATH=/Applications/EServer/Library/lib/pkgconfig \
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
--with-zlib-dir=/Applications/EServer/Library/zlib; then
  # configure 失败诊断：GD build test 失败时 conftest 仍保留在当前目录
  # 用 DYLD 调试变量重新运行，定位崩溃前最后加载的 dylib
  echo "=== configure 失败，运行 GD build test 诊断 ==="
  if [ -x ./conftest ]; then
    echo "--- DYLD_PRINT_LIBRARIES=1 ./conftest ---"
    DYLD_PRINT_LIBRARIES=1 DYLD_PRINT_RPATHS=1 ./conftest 2>&1 | head -200 || true
    echo "--- otool -L ./conftest ---"
    otool -L ./conftest || true
  fi
  # 检查 GD 依赖 dylib 链是否误链 Homebrew / /usr/local
  echo "=== GD 依赖 dylib 链检查 ==="
  for lib in freetype libpng libjpeg-turbo libwebp; do
    for dylib in /Applications/EServer/Library/$lib/lib/lib*.dylib; do
      [ -f "$dylib" ] || continue
      echo "--- $dylib ---"
      otool -L "$dylib" 2>/dev/null | grep -E "(/opt/homebrew|/usr/local|/Applications/EServer)" || echo "(无外部依赖)"
    done
  done
  exit 1
fi

# -------------------------------
# 编译安装
# -------------------------------
make -j"$(sysctl -n hw.ncpu 2>/dev/null || echo 8)"
sudo make install

sudo cp ./php.ini-development /Applications/EServer/childApp/php/php-7.3/etc/php.ini-development
sudo cp ./php.ini-production /Applications/EServer/childApp/php/php-7.3/etc/php.ini-production

# -------------------------------
# 完成提示
# -------------------------------
echo "PHP $PHP_VERSION installed to $PREFIX"
ls -l "$PREFIX/bin"
"$PREFIX/bin/php" -v

#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# 配置
# -------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/childApp/php/php-8.2}
PHP_VERSION=${PHP_VERSION:-8.2.27}

# build.log 固定落仓库根目录（脚本启动时的 cwd），不受后续 cd 影响
BUILD_LOG="$(pwd)/build.log"
: > "$BUILD_LOG"   # 预创建/清空，保证 configure 失败时文件也已存在

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
# 修正 ICU dylib install name（裸名 → 绝对路径）
# ICU 默认 build 出的 dylib install name 是裸文件名，
# 链接它的程序 load commands 只记录裸名，dyld 运行时找不到
# -------------------------------
ICU_LIB="/Applications/EServer/Library/icu/lib"
if [ -d "$ICU_LIB" ]; then
  echo "Fixing ICU dylib install names..."
  for f in "$ICU_LIB"/libicu*.dylib; do
    [ -f "$f" ] || continue
    base=$(basename "$f")
    install_name_tool -id "$f" "$f" 2>/dev/null || true
    for dep in $(otool -L "$f" | grep 'libicu' | awk '{print $1}'); do
      depname=$(basename "$dep")
      if [ "$dep" != "$base" ] && [ -f "$ICU_LIB/$depname" ]; then
        install_name_tool -change "$dep" "$ICU_LIB/$depname" "$f" 2>/dev/null || true
      fi
    done
  done
fi

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
# make 过程中会运行刚编译的 php（生成 phar），
# 需要让 dyld 找到 EServer Library 下的所有 dylib
# -------------------------------
export DYLD_FALLBACK_LIBRARY_PATH="/Applications/EServer/Library/icu/lib:/Applications/EServer/Library/libxml2/lib:/Applications/EServer/Library/libzip/lib:/Applications/EServer/Library/zlib/lib:/Applications/EServer/Library/oniguruma/lib:/Applications/EServer/Library/libgd/lib:/Applications/EServer/Library/curl/lib:/Applications/EServer/Library/openssl@3.5/lib:/Applications/EServer/Library/bzip2/lib:/Applications/EServer/Library/gmp/lib:/Applications/EServer/Library/libiconv/lib:/Applications/EServer/Library/libpq/lib${DYLD_FALLBACK_LIBRARY_PATH:+:$DYLD_FALLBACK_LIBRARY_PATH}"

make -j"$(sysctl -n hw.ncpu 2>/dev/null || echo 8)" V=1 2>&1 | tee "$BUILD_LOG"
sudo make install

sudo cp ./php.ini-development /Applications/EServer/childApp/php/php-8.2/etc/php.ini-development
sudo cp ./php.ini-production /Applications/EServer/childApp/php/php-8.2/etc/php.ini-production

# -------------------------------
# 删除 share 目录（若存在）
# -------------------------------
if [ -d "$PREFIX/share" ]; then
  echo "Removing share directory..."
  sudo rm -rf "$PREFIX/share"
fi

# -------------------------------
# 完成提示
# -------------------------------
echo "PHP $PHP_VERSION installed to $PREFIX"
ls -l "$PREFIX/bin"
"$PREFIX/bin/php" -v

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
: > "$BUILD_LOG"

# -------------------------------
# 下载源码
# shivammathur/php-src-backports：PHP 7.3.33 + 安全回溯，
# 归档已内置 patches/ 目录全部兼容补丁（ICU 70+、OpenSSL 3.0、
# libxml2 2.13、ITIMER_REAL、aarch64 inline asm 等，
# 已逐一 patch --dry-run --forward 验证为「已应用」）
# -------------------------------
TARBALL="php-src-backports-7.3.33.tar.gz"
URL="https://github.com/shivammathur/php-src-backports/archive/7.3.33.tar.gz"

mkdir -p build
cd build

if [ ! -f "$TARBALL" ]; then
  echo "Downloading PHP $PHP_VERSION from php-src-backports..."
  curl -fL -o "$TARBALL" "$URL"
fi

# -------------------------------
# 解压
# -------------------------------
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
export CXXFLAGS="${CXXFLAGS:+$CXXFLAGS} -stdlib=libc++"
export LDFLAGS="${LDFLAGS:+$LDFLAGS }-stdlib=libc++ -Wl,-headerpad_max_install_names"

# -------------------------------
# 清理旧文件 & 生成 configure
# -------------------------------
make clean 2>/dev/null || true
if [ ! -f configure ]; then
  echo "configure not found, running ./buildconf..."
  ./buildconf --force 2>&1 | tee -a "$BUILD_LOG"
fi

# -------------------------------
# 补丁
# 无需应用任何补丁：php-src-backports 归档源码已内置
# patch/php/ 清单（0001/0002/0003/0006/0007/0010/0011）中的全部修复
# -------------------------------

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
--disable-opcache \
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
--with-zlib-dir=/Applications/EServer/Library/zlib \
2>&1 | tee -a "$BUILD_LOG"

# -------------------------------
# 屏蔽XPM，https://bugs.php.net/bug.php?id=66204
# -------------------------------
echo "Custom: disable xpm"
sed -i '' '/HAVE_GD_XPM/d' main/php_config.h

# -------------------------------
# 编译安装
# -------------------------------
make -j"$(sysctl -n hw.ncpu 2>/dev/null || echo 8)" 2>&1 | tee -a "$BUILD_LOG"
sudo make install 2>&1 | tee -a "$BUILD_LOG"

sudo cp ./php.ini-development /Applications/EServer/childApp/php/php-7.3/etc/php.ini-development
sudo cp ./php.ini-production /Applications/EServer/childApp/php/php-7.3/etc/php.ini-production

# -------------------------------
# 完成提示
# -------------------------------
echo "PHP $PHP_VERSION installed to $PREFIX"
ls -l "$PREFIX/bin"
"$PREFIX/bin/php" -v

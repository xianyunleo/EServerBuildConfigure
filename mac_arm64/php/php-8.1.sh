#!/usr/bin/env bash
set -euo pipefail
set -E
trap 'rc=$?; echo "ERROR: command failed (exit $rc) at line $LINENO: $BASH_COMMAND" >&2; _f="${GITHUB_WORKSPACE:-/tmp}/failure.txt"; { printf "L%s: %s\n" "$LINENO" "$BASH_COMMAND"; if [ -f make.log ]; then grep -m 10 -E "error:|fatal error:" make.log | sed -E "s#$PWD/##g; s#^.*/((ext|Zend|main|sapi|TSRM)/[^:]+:[0-9]+:[0-9]+: )#\1#"; fi; } > "$_f" 2>/dev/null || true' ERR

# -------------------------------
# 配置
# -------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/childApp/php/php-8.1}
PHP_VERSION=${PHP_VERSION:-8.1.34}

# -------------------------------
# 下载源码（php-src 官方 CVE 修复分支）
# https://github.com/php/php-src/tree/PHP-8.1-CVE-2026-109618-109619
# -------------------------------
GIT_BRANCH="PHP-8.1-CVE-2026-109618-109619"
SRC_DIR="php-src-${GIT_BRANCH}"
TARBALL="${SRC_DIR}.tar.gz"
URL="https://github.com/php/php-src/archive/refs/heads/${GIT_BRANCH}.tar.gz"

mkdir -p build
cd build

if [ ! -f "$TARBALL" ]; then
  echo "Downloading php-src branch $GIT_BRANCH..."
  curl -L -o "$TARBALL" "$URL"
fi

# -------------------------------
# 解压
# -------------------------------
rm -rf "$SRC_DIR"
tar -xzf "$TARBALL"
echo "Source directory: $SRC_DIR"
cd "$SRC_DIR"

# -------------------------------
# 补丁
# 用反向 dry-run 判断，已应用则跳过，未应用则打上（幂等）。
# -------------------------------
apply_patch() {
  local f="$1"
  if [ ! -f "$f" ]; then
    echo "patch not found: $f" >&2
    return 1
  fi
  if patch -p1 -R --dry-run -s -f < "$f" >/dev/null 2>&1; then
    echo "already applied, skip: $(basename "$f")"
  else
    echo "applying: $(basename "$f")"
    patch -p1 < "$f"
  fi
}

apply_patch ../../patch/php/0006-Use-ITIMER_REAL-for-timeout-handling-PHP-8.1.patch

# -------------------------------
# 清理旧文件 & 生成 configure（git 分支源码不含 configure）
# -------------------------------
make clean 2>/dev/null || true
if [ ! -f configure ]; then
  echo "configure not found, running ./buildconf..."
  ./buildconf --force
fi

# -------------------------------
# 配置
# -------------------------------

# PHP 8.1 的 ext/bcmath/libbcmath 仍是 K&R 风格源码，不兼容 C23，强制使用 C17
export CFLAGS="${CFLAGS:+$CFLAGS }-std=gnu17"

# ICU 75+ 需要 C++17
export ICU_CXXFLAGS="-std=c++17"

export LIBS="${LIBS:+$LIBS }-lresolv"

# libxml2@2.11 的 pkgconfig 放在最前，覆盖 Library/lib 里指向 2.15.3 的
# libxml-2.0.pc（2.13+ 改了解析器的 instate 行为，ext/xml 的实体上报会出偏差；
# 2.11.9 仍按 ATTRIBUTE_VALUE/ENTITY_VALUE 维护状态，行为与 8.1 源码判断一致）
PKG_CONFIG_PATH=/Applications/EServer/Library/libxml2@2.11/lib/pkgconfig:/Applications/EServer/Library/lib/pkgconfig \
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
  --with-password-argon2=/Applications/EServer/Library/argon2 \
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
# -------------------------------
make -j"$(sysctl -n hw.ncpu 2>/dev/null || echo 8)" 2>&1 | tee make.log
sudo make install

sudo cp ./php.ini-development "$PREFIX/etc/php.ini-development"
sudo cp ./php.ini-production "$PREFIX/etc/php.ini-production"

# -------------------------------
# 完成提示
# -------------------------------
echo "PHP $PHP_VERSION installed to $PREFIX"
ls -l "$PREFIX/bin"
"$PREFIX/bin/php" -v


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

# GD build test 失败时 conftest 运行即 SIGILL，需 dyld 打印崩溃前最后加载的 dylib。
# 在 configure 前 export，使 configure 内部运行的所有 conftest 都把 dylib 加载信息输出到 stderr；
# autoconf 会把 conftest 的 stderr 重定向到 config.log，下次 config.log 即含诊断信息。
export DYLD_PRINT_LIBRARIES=1

set +e
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
CONFIGURE_EXIT=${PIPESTATUS[0]}
set -e
echo "=== configure end (exit: $CONFIGURE_EXIT) ===" >> "$BUILD_LOG"

if [ "$CONFIGURE_EXIT" -ne 0 ]; then
  echo "=== configure 失败，运行 GD 依赖诊断 ===" | tee -a "$BUILD_LOG"
  # GD build test 失败后 conftest 通常已被 configure 清理，用 config.log 里的源码+链接命令重建
  CONFTEST_C="$(pwd)/_gd_diag_conftest.c"
  cat > "$CONFTEST_C" <<'EOF'
char foobar () {}
char foobar();
int main() {
  foobar();
  return 0;
}
EOF
  echo "--- 重建 conftest 并用 DYLD 调试运行 ---" | tee -a "$BUILD_LOG"
  cc -o _gd_diag_conftest -g -O2 -fvisibility=hidden -no-cpp-precomp \
    -Wl,-rpath,/Applications/EServer/Library/libxml2/lib -L/Applications/EServer/Library/libxml2/lib \
    -Wl,-rpath,/Applications/EServer/Library/zlib/lib -L/Applications/EServer/Library/zlib/lib \
    -Wl,-rpath,/Applications/EServer/Library/bzip2/lib -L/Applications/EServer/Library/bzip2/lib \
    -Wl,-rpath,/Applications/EServer/Library/openssl@3.5/lib -L/Applications/EServer/Library/openssl@3.5/lib \
    "$CONFTEST_C" \
    -Wl,-rpath,/Applications/EServer/Library/freetype/lib -L/Applications/EServer/Library/freetype/lib \
    -Wl,-rpath,/Applications/EServer/Library/libpng/lib -L/Applications/EServer/Library/libpng/lib -lpng \
    -Wl,-rpath,/Applications/EServer/Library/zlib/lib -L/Applications/EServer/Library/zlib/lib -lz \
    -Wl,-rpath,/Applications/EServer/Library/libjpeg-turbo/lib -L/Applications/EServer/Library/libjpeg-turbo/lib -ljpeg \
    -Wl,-rpath,/Applications/EServer/Library/libwebp/lib -L/Applications/EServer/Library/libwebp/lib -lwebp \
    -lfreetype \
    -lcrypto -lssl -lcrypto -lbz2 -lz -lm \
    -lxml2 -lz -liconv -lxml2 -lz -liconv 2>&1 | tee -a "$BUILD_LOG" || true
  if [ -x ./_gd_diag_conftest ]; then
    echo "--- DYLD_PRINT_LIBRARIES=1 ./_gd_diag_conftest (前 200 行) ---" | tee -a "$BUILD_LOG"
    DYLD_PRINT_LIBRARIES=1 DYLD_PRINT_RPATHS=1 ./_gd_diag_conftest 2>&1 | head -200 | tee -a "$BUILD_LOG" || true
    echo "--- otool -L ./_gd_diag_conftest ---" | tee -a "$BUILD_LOG"
    otool -L ./_gd_diag_conftest 2>&1 | tee -a "$BUILD_LOG" || true
  fi
  # 检查 GD 依赖 dylib 链是否误链 Homebrew / /usr/local
  echo "=== GD 依赖 dylib 链检查 ===" | tee -a "$BUILD_LOG"
  for lib in freetype libpng libjpeg-turbo libwebp; do
    for dylib in /Applications/EServer/Library/$lib/lib/lib*.dylib; do
      [ -f "$dylib" ] || continue
      echo "--- $dylib ---" | tee -a "$BUILD_LOG"
      otool -L "$dylib" 2>/dev/null | grep -E "(/opt/homebrew|/usr/local|/Applications/EServer)" | tee -a "$BUILD_LOG" || echo "(无外部依赖)" | tee -a "$BUILD_LOG"
    done
  done
  exit 1
fi

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

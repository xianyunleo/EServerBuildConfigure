#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# 配置
# -------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/Library/bzip2}
BZIP2_VERSION=${BZIP2_VERSION:-1.0.8}  # 可以根据需要修改版本

# -------------------------------
# 下载源码
# -------------------------------
TARBALL="bzip2-${BZIP2_VERSION}.tar.gz"
URL="https://sourceware.org/pub/bzip2/$TARBALL"

mkdir -p build
cd build

if [ ! -f "$TARBALL" ]; then
  echo "Downloading bzip2 $BZIP2_VERSION..."
  curl -LO "$URL"
fi

# -------------------------------
# 解压
# -------------------------------
rm -rf "bzip2-${BZIP2_VERSION}"
tar -xzf "$TARBALL"
cd "bzip2-${BZIP2_VERSION}"

# -------------------------------
# 清理旧文件
# -------------------------------
make clean || true

# -------------------------------
# 编译对象文件
# -------------------------------
CFLAGS="-Wall -Winline -O2 -g -D_FILE_OFFSET_BITS=64"

for src in blocksort.c huffman.c crctable.c randtable.c compress.c decompress.c bzlib.c bzip2.c bzip2recover.c; do
  clang $CFLAGS -c "$src"
done

# -------------------------------
# 生成静态库
# -------------------------------
mkdir -p "$PREFIX/lib"
ar cq "$PREFIX/lib/libbz2.a" blocksort.o huffman.o crctable.o randtable.o compress.o decompress.o bzlib.o
ranlib "$PREFIX/lib/libbz2.a"

# -------------------------------
# 生成动态库 (macOS 专用)
# -------------------------------
clang -dynamiclib \
  blocksort.o huffman.o crctable.o randtable.o compress.o decompress.o bzlib.o \
  -install_name "$PREFIX/lib/libbz2.dylib" \
  -o "$PREFIX/lib/libbz2.dylib"

# -------------------------------
# 安装可执行文件
# -------------------------------
mkdir -p "$PREFIX/bin"
clang $CFLAGS -o bzip2 bzip2.o -L"$PREFIX/lib" -lbz2
clang $CFLAGS -o bzip2recover bzip2recover.o -L"$PREFIX/lib" -lbz2
mv bzip2 bzip2recover "$PREFIX/bin/"

# -------------------------------
# 安装头文件
# -------------------------------
mkdir -p "$PREFIX/include"
cp bzlib.h "$PREFIX/include/"

# -------------------------------
# 完成提示
# -------------------------------
echo "bzip2 $BZIP2_VERSION installed to $PREFIX"
ls -l "$PREFIX/lib"
ls -l "$PREFIX/include"
ls -l "$PREFIX/bin"

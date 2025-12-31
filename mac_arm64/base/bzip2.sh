#!/bin/bash
set -e

# -------------------------------
# 下载源码
# -------------------------------
curl -LO https://sourceware.org/pub/bzip2/bzip2-${BZIP2_VERSION}.tar.gz
tar -xzf bzip2-${BZIP2_VERSION}.tar.gz
cd bzip2-${BZIP2_VERSION}

# -------------------------------
# 清理旧文件
# -------------------------------
make clean || true

# -------------------------------
# 编译对象文件
# -------------------------------
CFLAGS="-Wall -Winline -O2 -g -D_FILE_OFFSET_BITS=64"

for src in blocksort.c huffman.c crctable.c randtable.c compress.c decompress.c bzlib.c bzip2.c bzip2recover.c; do
    clang $CFLAGS -c $src
done

# -------------------------------
# 生成静态库
# -------------------------------
ar cq libbz2.a blocksort.o huffman.o crctable.o randtable.o compress.o decompress.o bzlib.o
ranlib libbz2.a

# -------------------------------
# 生成动态库 (macOS 专用)
# -------------------------------
mkdir -p "$PREFIX/lib"
clang -dynamiclib \
  blocksort.o huffman.o crctable.o randtable.o compress.o decompress.o bzlib.o \
  -install_name "$PREFIX/lib/libbz2.dylib" \
  -o "$PREFIX/lib/libbz2.dylib"

# -------------------------------
# 安装可执行文件
# -------------------------------
mkdir -p "$PREFIX/bin"
clang $CFLAGS -o bzip2 bzip2.o -L. -lbz2
clang $CFLAGS -o bzip2recover bzip2recover.o -L. -lbz2
mv bzip2 bzip2recover "$PREFIX/bin/"

# -------------------------------
# 安装头文件
# -------------------------------
mkdir -p "$PREFIX/include"
cp bzlib.h "$PREFIX/include/"

echo "安装完成: $PREFIX"

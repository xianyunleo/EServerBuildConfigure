#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------
# 配置
# -------------------------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/Library/icu}
ICU_VERSION=${ICU_VERSION:-78.3}

# -------------------------------------------------
# 下载源码
# -------------------------------------------------
TARBALL="icu4c-${ICU_VERSION}-sources.tgz"
URL="https://github.com/unicode-org/icu/releases/download/release-${ICU_VERSION}/${TARBALL}"

mkdir -p "$PREFIX" build
cd build

if [ ! -f "$TARBALL" ]; then
  echo "Downloading ICU $ICU_VERSION..."
  curl -fL -o "$TARBALL" "$URL"
fi

# -------------------------------------------------
# 解压
# -------------------------------------------------
rm -rf icu
tar -xzf "$TARBALL"

# ICU 源码在 icu/source 目录
cd icu/source

# -------------------------------------------------
# 清理旧文件
# -------------------------------------------------
make clean 2>/dev/null || true

# -------------------------------------------------
# 配置
# -------------------------------------------------
CFLAGS="-O2" \
CXXFLAGS="$CFLAGS" \
./configure --prefix="$PREFIX" \
--enable-rpath
--disable-samples \
--disable-tests \
--enable-static \
--with-library-bits=64

# -------------------------------------------------
# 编译安装
# -------------------------------------------------
make -j"$(sysctl -n hw.ncpu 2>/dev/null || echo 8)"
make install

# 删除 share 目录（不需要的文件）
if [ -d "$PREFIX/share" ]; then
  sudo rm -rf "$PREFIX/share"
fi

# -------------------------------------------------
# 修正 dylib install name（裸名 → 绝对路径）
# 不修正的话，链接 ICU 的程序（如 PHP）load commands
# 里只记录裸文件名，dyld 运行时找不到库
# -------------------------------------------------
echo "Fixing dylib install names..."
for f in "$PREFIX/lib"/libicu*.dylib; do
  [ -f "$f" ] || continue
  base=$(basename "$f")
  # 修正自身 install name (LC_ID_DYLIB)
  install_name_tool -id "$f" "$f"
  # 修正对其他 ICU dylib 的内部引用
  for dep in $(otool -L "$f" | grep 'libicu' | awk '{print $1}'); do
    depname=$(basename "$dep")
    if [ "$dep" != "$base" ] && [ -f "$PREFIX/lib/$depname" ]; then
      install_name_tool -change "$dep" "$PREFIX/lib/$depname" "$f"
    fi
  done
done

# -------------------------------------------------
# 完成提示
# -------------------------------------------------
echo "ICU $ICU_VERSION installed to $PREFIX"
ls -l "$PREFIX/lib"

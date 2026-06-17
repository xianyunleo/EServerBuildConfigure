#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# 配置
# -------------------------------
export MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET:-11.0}
PREFIX=${PREFIX:-/Applications/EServer/childApp/server/nginx}
NGINX_VERSION=${NGINX_VERSION:-1.30.2}

# -------------------------------
# 下载源码
# -------------------------------
TARBALL="nginx-${NGINX_VERSION}.tar.gz"
URL="https://nginx.org/download/$TARBALL"

mkdir -p build
cd build

if [ ! -f "$TARBALL" ]; then
  echo "Downloading nginx $NGINX_VERSION..."
  curl -LO "$URL"
fi

# -------------------------------
# 解压
# -------------------------------
rm -rf "nginx-${NGINX_VERSION}"
tar -xzf "$TARBALL"
cd "nginx-${NGINX_VERSION}"

# -------------------------------
# 清理旧文件
# -------------------------------
make clean || true

# -------------------------------
# 配置
# -------------------------------
# 1. 下载
curl -L -o MacOSX11.3.tar.bz2 \
https://github.com/alexey-lysiuk/macos-sdk/releases/download/11.3/MacOSX11.3.tar.bz2

# 2. 安装目录
sudo mkdir -p /opt/sdks

# 3. 解压
sudo tar -xjf MacOSX11.3.tar.bz2 -C /opt/sdks

# 4. 检查
ls /opt/sdks/MacOSX11.3.sdk

export SDKROOT=/opt/sdks/MacOSX11.3.sdk

./configure --prefix="$PREFIX" \
--with-cc-opt="-I/Applications/EServer/Library/pcre2/include -I/Applications/EServer/Library/openssl@3.5/include -I/Applications/EServer/Library/zlib/include" \
  --with-ld-opt="-L/Applications/EServer/Library/pcre2/lib -L/Applications/EServer/Library/openssl@3.5/lib -L/Applications/EServer/Library/zlib/lib" \
  --with-compat \
  --with-debug \
  --with-http_addition_module \
  --with-http_auth_request_module \
  --with-http_dav_module \
  --with-http_degradation_module \
  --with-http_flv_module \
  --with-http_gunzip_module \
  --with-http_gzip_static_module \
  --with-http_mp4_module \
  --with-http_random_index_module \
  --with-http_realip_module \
  --with-http_secure_link_module \
  --with-http_slice_module \
  --with-http_ssl_module \
  --with-http_stub_status_module \
  --with-http_sub_module \
  --with-http_v2_module \
  --with-http_v3_module \
  --with-mail \
  --with-mail_ssl_module \
  --with-pcre \
  --with-pcre-jit \
  --with-stream \
  --with-stream_realip_module \
  --with-stream_ssl_module \
  --with-stream_ssl_preread_module

# -------------------------------
# 编译安装
# -------------------------------
sudo make -j8
sudo make install

# -------------------------------
# 完成提示
# -------------------------------
echo "nginx $NGINX_VERSION installed to $PREFIX"
ls -l "$PREFIX/sbin"

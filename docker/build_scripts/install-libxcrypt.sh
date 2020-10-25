#!/bin/bash
# Top-level build script called from Dockerfile

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
source $MY_DIR/build_utils.sh

# Install libcrypt.so.1 and libcrypt.so.2
LIBXCRYPT_VERSION=4.4.17
LIBXCRYPT_DOWNLOAD_URL=https://codeload.github.com/besser82/libxcrypt/tar.gz
LIBXCRYPT_HASH=7665168d0409574a03f7b484682e68334764c29c21ca5df438955a381384ca07


curl -fsSLO "$LIBXCRYPT_DOWNLOAD_URL"/v"$LIBXCRYPT_VERSION"
check_sha256sum "v$LIBXCRYPT_VERSION" "$LIBXCRYPT_HASH"
tar xfz "v$LIBXCRYPT_VERSION"
pushd "libxcrypt-$LIBXCRYPT_VERSION"
./autogen.sh > /dev/null
do_standard_install \
	--disable-obsolete-api \
	--enable-hashes=all \
	--disable-werror
# we also need libcrypt.so.1 with glibc compatibility for system libraries
# c.f https://github.com/pypa/manylinux/issues/305#issuecomment-625902928
make clean > /dev/null
sed -r -i 's/XCRYPT_([0-9.])+/-/g;s/(%chain OW_CRYPT_1.0).*/\1/g' lib/libcrypt.map.in
DESTDIR=$(pwd)/so.1 do_standard_install \
	--disable-xcrypt-compat-files \
	--enable-obsolete-api=glibc \
	--enable-hashes=all \
	--disable-werror
cp -P ./so.1/usr/local/lib/libcrypt.so.1* /usr/local/lib/
popd
rm -rf "v$LIBXCRYPT_VERSION" "libxcrypt-$LIBXCRYPT_VERSION"

# Delete GLIBC version headers and libraries
rm -rf /usr/include/crypt.h
rm -rf /usr/lib*/libcrypt.a /usr/lib*/libcrypt.so /usr/lib*/libcrypt.so.1

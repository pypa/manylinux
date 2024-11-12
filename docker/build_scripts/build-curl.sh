#!/bin/bash
# Top-level build script called from Dockerfile

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
source $MY_DIR/build_utils.sh

# Install a more recent curl
check_var ${CURL_ROOT}
check_var ${CURL_HASH}
check_var ${CURL_DOWNLOAD_URL}

# Only needed on manylinux2014
if [ "${AUDITWHEEL_POLICY}" != "manylinux2014" ]; then
	echo "skipping installation of ${CURL_ROOT}"
	exit 0
fi

if which yum; then
	yum erase -y curl-devel
else
	apk del curl-dev
fi

SO_COMPAT=4
PREFIX=/opt/_internal/curl-${SO_COMPAT}

fetch_source ${CURL_ROOT}.tar.gz ${CURL_DOWNLOAD_URL}
check_sha256sum ${CURL_ROOT}.tar.gz ${CURL_HASH}
tar -xzf ${CURL_ROOT}.tar.gz
pushd ${CURL_ROOT}
./configure --prefix=${PREFIX} --disable-static --without-libpsl --with-openssl CPPFLAGS="${MANYLINUX_CPPFLAGS}" CFLAGS="${MANYLINUX_CFLAGS}" CXXFLAGS="${MANYLINUX_CXXFLAGS}" LDFLAGS="${MANYLINUX_LDFLAGS} -Wl,-rpath=\$(LIBRPATH)" > /dev/null
make > /dev/null
make install > /dev/null
popd
rm -rf ${CURL_ROOT} ${CURL_ROOT}.tar.gz ${PREFIX}/share/man

if [ ! -f ${PREFIX}/lib/libcurl.so.${SO_COMPAT} ]; then
	echo "please update SO_COMPAT"
	ls -al ${PREFIX}/lib
	exit 1
fi

strip_ ${PREFIX}

${PREFIX}/bin/curl --version
${PREFIX}/bin/curl-config --features

mkdir -p /manylinux-rootfs/${PREFIX}/lib
cp -f ${PREFIX}/lib/libcurl.so.${SO_COMPAT} /manylinux-rootfs/${PREFIX}/lib/

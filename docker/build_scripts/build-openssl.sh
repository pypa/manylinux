#!/bin/bash
# Top-level build script called from Dockerfile

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
source $MY_DIR/build_utils.sh

# Install a more recent openssl
OPENSSL_MIN_VERSION=1.0.2
OPENSSL_VERSION=1.1.1i
OPENSSL_ROOT=openssl-${OPENSSL_VERSION}
OPENSSL_HASH=e8be6a35fe41d10603c3cc635e93289ed00bf34b79671a3a4de64fcee00d5242
OPENSSL_DOWNLOAD_URL=https://www.openssl.org/source


INSTALLED=$(openssl version | head -1 | awk '{ print $2 }')
SMALLEST=$(echo -e "${INSTALLED}\n${OPENSSL_MIN_VERSION}" | sort -t. -k 1,1n -k 2,2n -k 3,3n -k 4,4n | head -1)
if [ "${SMALLEST}" == "${OPENSSL_MIN_VERSION}" ]; then
	echo "skipping installation of openssl ${OPENSSL_VERSION}, system provides openssl ${INSTALLED} which is newer than openssl ${OPENSSL_MIN_VERSION}"
	exit 0
fi

if which yum; then
	yum erase -y openssl-devel
else
	apt-get remove -y libssl-dev
fi

fetch_source ${OPENSSL_ROOT}.tar.gz ${OPENSSL_DOWNLOAD_URL}
check_sha256sum ${OPENSSL_ROOT}.tar.gz ${OPENSSL_HASH}
tar -xzf ${OPENSSL_ROOT}.tar.gz
pushd ${OPENSSL_ROOT}
./config no-shared -fPIC --prefix=/usr/local/ssl --openssldir=/usr/local/ssl > /dev/null
make > /dev/null
make install_sw > /dev/null
popd
rm -rf ${OPENSSL_ROOT} ${OPENSSL_ROOT}.tar.gz


/usr/local/ssl/bin/openssl version

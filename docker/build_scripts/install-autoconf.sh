#!/bin/bash
# Top-level build script called from Dockerfile

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
source $MY_DIR/build_utils.sh


# Install newest autoconf
AUTOCONF_VERSION=2.69
AUTOCONF_ROOT=autoconf-${AUTOCONF_VERSION}
AUTOCONF_HASH=954bd69b391edc12d6a4a51a2dd1476543da5c6bbf05a95b59dc0dd6fd4c2969
AUTOCONF_DOWNLOAD_URL=http://ftp.gnu.org/gnu/autoconf


if autoconf --version > /dev/null 2>&1; then
	INSTALLED=$(autoconf --version | head -1 | awk '{ print $NF }')
	SMALLEST=$(echo -e "${INSTALLED}\n${AUTOCONF_VERSION}" | sort -t. -k 1,1n -k 2,2n -k 3,3n -k 4,4n | head -1)
	if [ "${SMALLEST}" == "${AUTOCONF_VERSION}" ]; then
		echo "skipping installation of autoconf ${AUTOCONF_VERSION}, system provides autoconf ${INSTALLED}"
		exit 0
	fi
fi


fetch_source ${AUTOCONF_ROOT}.tar.gz ${AUTOCONF_DOWNLOAD_URL}
check_sha256sum ${AUTOCONF_ROOT}.tar.gz ${AUTOCONF_HASH}
tar -zxf ${AUTOCONF_ROOT}.tar.gz
pushd ${AUTOCONF_ROOT}
do_standard_install
popd
rm -rf ${AUTOCONF_ROOT} ${AUTOCONF_ROOT}.tar.gz


hash -r
autoconf --version

#!/bin/bash
# Top-level build script called from Dockerfile

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
source $MY_DIR/build_utils.sh

# Install newest automake
check_var ${AUTOMAKE_ROOT}
check_var ${AUTOMAKE_HASH}
check_var ${AUTOMAKE_DOWNLOAD_URL}

AUTOMAKE_VERSION=${AUTOMAKE_ROOT#*-}
if automake --version > /dev/null 2>&1; then
	# || test $? -eq 141 is there to ignore SIGPIPE with set -o pipefail
	# c.f. https://stackoverflow.com/questions/22464786/ignoring-bash-pipefail-for-error-code-141#comment60412687_33026977
	INSTALLED=$((automake --version | head -1 || test $? -eq 141) | awk '{ print $NF }')
	SMALLEST=$(echo -e "${INSTALLED}\n${AUTOMAKE_VERSION}" | sort -t. -k 1,1n -k 2,2n -k 3,3n -k 4,4n | head -1 || test $? -eq 141)
	if [ "${SMALLEST}" == "${AUTOMAKE_VERSION}" ]; then
		echo "skipping installation of automake ${AUTOMAKE_VERSION}, system provides automake ${INSTALLED}"
		exit 0
	fi
fi

fetch_source ${AUTOMAKE_ROOT}.tar.gz ${AUTOMAKE_DOWNLOAD_URL}
check_sha256sum ${AUTOMAKE_ROOT}.tar.gz ${AUTOMAKE_HASH}
tar -zxf ${AUTOMAKE_ROOT}.tar.gz
pushd ${AUTOMAKE_ROOT}
DESTDIR=/manylinux-rootfs do_standard_install
popd
rm -rf ${AUTOMAKE_ROOT} ${AUTOMAKE_ROOT}.tar.gz

# Strip what we can
strip_ /manylinux-rootfs

# Install
cp -rlf /manylinux-rootfs/* /

# Remove temporary rootfs
rm -rf /manylinux-rootfs

hash -r
automake --version

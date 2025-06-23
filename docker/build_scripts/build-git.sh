#!/bin/bash
# Top-level build script called from Dockerfile

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
# shellcheck source-path=SCRIPTDIR
source "${MY_DIR}/build_utils.sh"

if [ "${BASE_POLICY}" == "musllinux" ]; then
	export NO_REGEX=NeedsStartEnd
fi

if [ "${AUDITWHEEL_POLICY}" == "manylinux2014" ]; then
	export NO_UNCOMPRESS2=1
	CSPRNG_METHOD=urandom
	# workaround build issue when openssl gets included
	# git provides its own implementation of ctypes which conflicts
	# with the one in CentOS 7. Just use the one from git.
	echo "" > /usr/include/ctype.h
else
	CSPRNG_METHOD=getrandom
fi

if [ -d /opt/_internal ]; then
	CURL_PREFIX=$(find /opt/_internal -maxdepth 1 -name 'curl-*')
	if [ "${CURL_PREFIX}" != "" ]; then
		export CURLDIR=${CURL_PREFIX}
		CURL_LDFLAGS="-Wl,-rpath=${CURL_PREFIX}/lib $("${CURL_PREFIX}/bin/curl-config" --libs)"
		export CURL_LDFLAGS
	fi
fi

# Install newest git
check_var "${GIT_ROOT}"
check_var "${GIT_HASH}"
check_var "${GIT_DOWNLOAD_URL}"

fetch_source "${GIT_ROOT}.tar.gz" "${GIT_DOWNLOAD_URL}"
check_sha256sum "${GIT_ROOT}.tar.gz" "${GIT_HASH}"
tar -xzf "${GIT_ROOT}.tar.gz"
pushd "${GIT_ROOT}"
make install prefix=/usr/local NO_GETTEXT=1 NO_TCLTK=1 DESTDIR=/manylinux-rootfs CSPRNG_METHOD=${CSPRNG_METHOD} CPPFLAGS="${MANYLINUX_CPPFLAGS}" CFLAGS="${MANYLINUX_CFLAGS}" CXXFLAGS="${MANYLINUX_CXXFLAGS}" LDFLAGS="${MANYLINUX_LDFLAGS}"
popd
rm -rf "${GIT_ROOT}" "${GIT_ROOT}.tar.gz"


# Strip what we can
strip_ /manylinux-rootfs

# Install
cp -rlf /manylinux-rootfs/* /

git version

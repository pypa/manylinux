#!/bin/bash
# Top-level build script called from Dockerfile

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
# shellcheck source-path=SCRIPTDIR
source "${MY_DIR}/build_utils.sh"

# Install newest libtool
if ! fetch_source "${LIBTOOL_ROOT}.tar.gz" "${LIBTOOL_DOWNLOAD_URL}" "${LIBTOOL_HASH}"; then
	fetch_source "${LIBTOOL_ROOT}.tar.gz" "${LIBTOOL_DOWNLOAD_URL/ftpmirror.gnu.org/mirrors.ocf.berkeley.edu}" "${LIBTOOL_HASH}"
fi
tar -zxf "${LIBTOOL_ROOT}.tar.gz"
pushd "${LIBTOOL_ROOT}"
DESTDIR=/manylinux-rootfs do_standard_install
popd
rm -rf "${LIBTOOL_ROOT}" "${LIBTOOL_ROOT}.tar.gz"

# Strip what we can
strip_ /manylinux-rootfs

# Install
cp -rlf /manylinux-rootfs/* /

# Remove temporary rootfs
rm -rf /manylinux-rootfs

hash -r
libtoolize --version

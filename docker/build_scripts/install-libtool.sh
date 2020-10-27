#!/bin/bash
# Top-level build script called from Dockerfile

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
source $MY_DIR/build_utils.sh

# Install newest libtool
LIBTOOL_VERSION=2.4.6
LIBTOOL_ROOT=libtool-${LIBTOOL_VERSION}
LIBTOOL_HASH=e3bd4d5d3d025a36c21dd6af7ea818a2afcd4dfc1ea5a17b39d7854bcd0c06e3
LIBTOOL_DOWNLOAD_URL=http://ftp.gnu.org/gnu/libtool


fetch_source ${LIBTOOL_ROOT}.tar.gz ${LIBTOOL_DOWNLOAD_URL}
check_sha256sum ${LIBTOOL_ROOT}.tar.gz ${LIBTOOL_HASH}
tar -zxf ${LIBTOOL_ROOT}.tar.gz
pushd ${LIBTOOL_ROOT}
do_standard_install
popd
rm -rf ${LIBTOOL_ROOT} ${LIBTOOL_ROOT}.tar.gz


hash -r
libtoolize --version

#!/bin/bash
# Top-level build script called from Dockerfile

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
source $MY_DIR/build_utils.sh

# Install newest automake
AUTOMAKE_ROOT=automake-1.16.2
AUTOMAKE_HASH=b2f361094b410b4acbf4efba7337bdb786335ca09eb2518635a09fb7319ca5c1
AUTOMAKE_DOWNLOAD_URL=http://ftp.gnu.org/gnu/automake


fetch_source ${AUTOMAKE_ROOT}.tar.gz ${AUTOMAKE_DOWNLOAD_URL}
check_sha256sum ${AUTOMAKE_ROOT}.tar.gz ${AUTOMAKE_HASH}
tar -zxf ${AUTOMAKE_ROOT}.tar.gz
pushd ${AUTOMAKE_ROOT}
do_standard_install
popd
rm -rf ${AUTOMAKE_ROOT} ${AUTOMAKE_ROOT}.tar.gz


automake --version

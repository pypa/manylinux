#!/bin/bash
# Top-level build script called from Dockerfile

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
source $MY_DIR/build_utils.sh

# Install a more recent SQLite3
check_var ${SQLITE_AUTOCONF_ROOT}
check_var ${SQLITE_AUTOCONF_HASH}
check_var ${SQLITE_AUTOCONF_DOWNLOAD_URL}
fetch_source ${SQLITE_AUTOCONF_ROOT}.tar.gz ${SQLITE_AUTOCONF_DOWNLOAD_URL}
check_sha256sum ${SQLITE_AUTOCONF_ROOT}.tar.gz ${SQLITE_AUTOCONF_HASH}
tar xfz ${SQLITE_AUTOCONF_ROOT}.tar.gz
pushd ${SQLITE_AUTOCONF_ROOT}
DESTDIR=/manylinux-rootfs do_standard_install
popd
rm -rf ${SQLITE_AUTOCONF_ROOT} ${SQLITE_AUTOCONF_ROOT}.tar.gz

# static library is unused, remove it
rm /manylinux-rootfs/usr/local/lib/libsqlite3.a

# Strip what we can
strip_ /manylinux-rootfs

# Install
cp -rf /manylinux-rootfs/* /

# Clean-up for runtime
rm -rf /manylinux-rootfs/usr/local/bin /manylinux-rootfs/usr/local/include /manylinux-rootfs/usr/local/lib/pkg-config /manylinux-rootfs/usr/local/share
find -L /manylinux-rootfs -type f -a -not -name 'libsqlite3.so.*' -delete

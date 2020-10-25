#!/bin/bash
# Top-level build script called from Dockerfile

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
source $MY_DIR/build_utils.sh

# Install a more recent SQLite3
SQLITE_AUTOCONF_VERSION=sqlite-autoconf-3330000
SQLITE_AUTOCONF_HASH=106a2c48c7f75a298a7557bcc0d5f4f454e5b43811cc738b7ca294d6956bbb15
SQLITE_AUTOCONF_DOWNLOAD_URL=https://www.sqlite.org/2020


fetch_source ${SQLITE_AUTOCONF_VERSION}.tar.gz ${SQLITE_AUTOCONF_DOWNLOAD_URL}
check_sha256sum ${SQLITE_AUTOCONF_VERSION}.tar.gz ${SQLITE_AUTOCONF_HASH}
tar xfz ${SQLITE_AUTOCONF_VERSION}.tar.gz
pushd ${SQLITE_AUTOCONF_VERSION}
DESTDIR=/manylinux/sqlite3 do_standard_install
popd
rm -rf ${SQLITE_AUTOCONF_VERSION} ${SQLITE_AUTOCONF_VERSION}.tar.gz

# static library is unused, remove it
rm /manylinux/sqlite3/usr/local/lib/libsqlite3.a

# Install
cp -rf /manylinux/sqlite3/* /

# Clean-up for runtime
rm -rf /manylinux/sqlite3/usr/local/bin /manylinux/sqlite3/usr/local/include /manylinux/sqlite3/usr/local/lib/pkg-config /manylinux/sqlite3/usr/local/share
find -L manylinux/sqlite3 -type f -a -not -name 'libsqlite3.so.*' -delete

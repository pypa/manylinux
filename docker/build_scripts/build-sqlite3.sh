#!/bin/bash
# Top-level build script called from Dockerfile

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
source $MY_DIR/build_utils.sh

if [ "${AUDITWHEEL_POLICY}" == "manylinux2014" ] || [ "${AUDITWHEEL_POLICY}" == "manylinux_2_28" ] || [ "${AUDITWHEEL_POLICY}" == "musllinux_1_2" ]; then
	PREFIX=/usr/local
else
	PREFIX=/opt/_internal/sqlite3
fi

# Install a more recent SQLite3
check_var ${SQLITE_AUTOCONF_ROOT}
check_var ${SQLITE_AUTOCONF_HASH}
check_var ${SQLITE_AUTOCONF_DOWNLOAD_URL}
fetch_source ${SQLITE_AUTOCONF_ROOT}.tar.gz ${SQLITE_AUTOCONF_DOWNLOAD_URL}
check_sha256sum ${SQLITE_AUTOCONF_ROOT}.tar.gz ${SQLITE_AUTOCONF_HASH}
tar xfz ${SQLITE_AUTOCONF_ROOT}.tar.gz
pushd ${SQLITE_AUTOCONF_ROOT}
# add rpath
sed -i "s|^Libs:|Libs: -Wl,--enable-new-dtags,-rpath=\${libdir} |g" sqlite3.pc.in
DESTDIR=/manylinux-rootfs do_standard_install --prefix=${PREFIX}
popd
rm -rf ${SQLITE_AUTOCONF_ROOT} ${SQLITE_AUTOCONF_ROOT}.tar.gz

# Remove unused files
rm /manylinux-rootfs${PREFIX}/lib/libsqlite3.a
rm -rf /manylinux-rootfs${PREFIX}/share

# Strip what we can
strip_ /manylinux-rootfs

# Install for build
mkdir /manylinux-buildfs
cp -rlf /manylinux-rootfs/* /manylinux-buildfs/

if [ "${PREFIX}" == "/opt/_internal/sqlite3" ]; then
	# python >= 3.11
	mkdir -p /manylinux-buildfs/usr/local/lib/pkgconfig/
	ln -s ${PREFIX}/lib/pkgconfig/sqlite3.pc /manylinux-buildfs/usr/local/lib/pkgconfig/sqlite3.pc
fi

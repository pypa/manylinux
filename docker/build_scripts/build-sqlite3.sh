#!/bin/bash
# Top-level build script called from Dockerfile

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
source $MY_DIR/build_utils.sh

if [ "${AUDITWHEEL_POLICY}" != "manylinux_2_34" ]; then
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
export CFLAGS="-Wall -fno-strict-aliasing -DSQLITE_ENABLE_FTS3_PARENTHESIS=1 -DSQLITE_ENABLE_FTS4=1 -DSQLITE_ENABLE_FTS5=1 -DSQLITE_ENABLE_RTREE=1 -DSQLITE_OMIT_AUTOINIT -DSQLITE_TCL=0"
DESTDIR=/manylinux-rootfs do_standard_install --prefix=${PREFIX} --enable-threadsafe --enable-shared=yes --enable-static=no --enable-fts4 --enable-fts5 --disable-dependency-tracking
popd
rm -rf ${SQLITE_AUTOCONF_ROOT} ${SQLITE_AUTOCONF_ROOT}.tar.gz

# Strip what we can
strip_ /manylinux-rootfs

# Install
cp -rlf /manylinux-rootfs/* /

if [ "${PREFIX}" == "/usr/local" ]; then
	if [ "${BASE_POLICY}" == "musllinux" ]; then
		ldconfig /
	elif [ "${BASE_POLICY}" == "manylinux" ]; then
		ldconfig
	fi
else
	# python >= 3.11
	mkdir -p /usr/local/lib/pkgconfig/
	ln -s ${PREFIX}/lib/pkgconfig/sqlite3.pc /usr/local/lib/pkgconfig/sqlite3.pc
fi

# Clean-up for runtime
rm -rf /manylinux-rootfs${PREFIX}/share

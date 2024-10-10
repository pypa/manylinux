#!/bin/bash
# Top-level build script called from Dockerfile

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
source $MY_DIR/build_utils.sh

if [ "${AUDITWHEEL_POLICY}" == "manylinux2014" ] || [ "${AUDITWHEEL_POLICY}" == "manylinux_2_28" ] || [ "${AUDITWHEEL_POLICY}" == "musllinux_1_1" ] || [ "${AUDITWHEEL_POLICY}" == "musllinux_1_2" ]; then
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

#!/bin/bash
# Top-level build script called from Dockerfile

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
source $MY_DIR/build_utils.sh

# Install a more recent Tcl/Tk 8.6
# https://www.tcl.tk/software/tcltk/download.html
check_var ${TCL_ROOT}
check_var ${TCL_HASH}
check_var ${TCL_DOWNLOAD_URL}
check_var ${TK_ROOT}
check_var ${TK_HASH}

if [ "${AUDITWHEEL_POLICY}" == "manylinux2014" ] ; then
	yum erase -y tcl tk
else
	exit 0
fi

fetch_source ${TCL_ROOT}-src.tar.gz ${TCL_DOWNLOAD_URL}
check_sha256sum ${TCL_ROOT}-src.tar.gz ${TCL_HASH}
fetch_source ${TK_ROOT}-src.tar.gz ${TCL_DOWNLOAD_URL}
check_sha256sum ${TK_ROOT}-src.tar.gz ${TK_HASH}

tar xfz ${TCL_ROOT}-src.tar.gz
pushd ${TCL_ROOT}/unix
DESTDIR=/manylinux-rootfs do_standard_install
popd

tar xfz ${TK_ROOT}-src.tar.gz
pushd ${TK_ROOT}/unix
DESTDIR=/manylinux-rootfs do_standard_install
popd

# Remove only after building is complete
rm -rf ${TCL_ROOT} ${TCL_ROOT}-src.tar.gz
rm -rf ${TK_ROOT} ${TK_ROOT}-src.tar.gz

# Static library is unused, remove it
rm /manylinux-rootfs/usr/local/lib/libtclstub8.6.a
rm /manylinux-rootfs/usr/local/lib/libtkstub8.6.a

# Strip what we can
strip_ /manylinux-rootfs

# Install
cp -rlf /manylinux-rootfs/* /
if [ "${BASE_POLICY}" == "musllinux" ]; then
	ldconfig /
elif [ "${BASE_POLICY}" == "manylinux" ]; then
	ldconfig
fi

# Clean-up for runtime
rm -rf /manylinux-rootfs/usr/local/share

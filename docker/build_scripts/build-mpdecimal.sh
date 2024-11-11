#!/bin/bash
# Top-level build script called from Dockerfile

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
source $MY_DIR/build_utils.sh

# Install a more recent mpdecimal
check_var ${MPDECIMAL_ROOT}
check_var ${MPDECIMAL_HASH}
check_var ${MPDECIMAL_DOWNLOAD_URL}

PREFIX=/opt/_internal/${MPDECIMAL_ROOT%%.*}

fetch_source ${MPDECIMAL_ROOT}.tar.gz ${MPDECIMAL_DOWNLOAD_URL}
check_sha256sum ${MPDECIMAL_ROOT}.tar.gz ${MPDECIMAL_HASH}
tar xfz ${MPDECIMAL_ROOT}.tar.gz
pushd ${MPDECIMAL_ROOT}
# add rpath
sed -i "s|^Libs:|Libs: -Wl,--enable-new-dtags,-rpath=\${libdir} |g" ./libmpdec/.pc/libmpdec.pc.in
DESTDIR=/manylinux-rootfs do_standard_install --prefix=${PREFIX} --enable-shared --enable-pc --disable-doc --disable-static --disable-cxx
popd
rm -rf ${MPDECIMAL_ROOT} ${MPDECIMAL_ROOT}.tar.gz

# Strip what we can
strip_ /manylinux-rootfs

# Install for build
mkdir /manylinux-buildfs
cp -rlf /manylinux-rootfs/* /manylinux-buildfs/
# copy pkgconfig
mkdir -p /manylinux-buildfs/usr/local/lib/pkgconfig/
ln -s ${PREFIX}/lib/pkgconfig/libmpdec.pc /manylinux-buildfs/usr/local/lib/pkgconfig/libmpdec.pc

# Clean-up for runtime
rm -rf /manylinux-rootfs/${PREFIX}/lib/pkgconfig /manylinux-rootfs/${PREFIX}/include

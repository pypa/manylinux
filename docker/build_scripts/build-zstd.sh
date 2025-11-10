#!/bin/bash
# Top-level build script called from Dockerfile

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
# shellcheck source-path=SCRIPTDIR
source "${MY_DIR}/build_utils.sh"

# Install a more recent mpdecimal
check_var "${ZSTD_VERSION}"
check_var "${ZSTD_HASH}"
check_var "${ZSTD_DOWNLOAD_URL}"
ZSTD_ROOT="zstd-${ZSTD_VERSION}"

PREFIX=/opt/_internal/${ZSTD_ROOT%%.*}

fetch_source "${ZSTD_ROOT}.tar.gz" "${ZSTD_DOWNLOAD_URL}/v${ZSTD_VERSION}"
check_sha256sum "${ZSTD_ROOT}.tar.gz" "${ZSTD_HASH}"
tar xfz "${ZSTD_ROOT}.tar.gz"
pushd "${ZSTD_ROOT}/lib"
# add rpath
sed -i "s|^Libs:|Libs: -Wl,--enable-new-dtags,-rpath=\${libdir} |g" ./libzstd.pc.in
DESTDIR=/manylinux-rootfs MT=1 prefix=${PREFIX} make install-includes install-pc install-shared V=1 CPPFLAGS="${MANYLINUX_CPPFLAGS} -DZSTD_MULTITHREAD" CFLAGS="${MANYLINUX_CFLAGS} -DZSTD_MULTITHREAD -pthread -fPIC -fvisibility=hidden" LDFLAGS="${MANYLINUX_LDFLAGS} -shared -pthread"
popd
rm -rf "${ZSTD_ROOT}" "${ZSTD_ROOT}.tar.gz"

# Strip what we can
strip_ /manylinux-rootfs

# Install for build
mkdir /manylinux-buildfs
cp -rlf /manylinux-rootfs/* /manylinux-buildfs/
# copy pkgconfig
mkdir -p /manylinux-buildfs/usr/local/lib/pkgconfig/
ln -s "${PREFIX}/lib/pkgconfig/libzstd.pc" /manylinux-buildfs/usr/local/lib/pkgconfig/libzstd.pc

# Clean-up for runtime
rm -rf "/manylinux-rootfs/${PREFIX}/lib/pkgconfig" "/manylinux-rootfs/${PREFIX}/include"

#!/bin/bash
# Top-level build script called from Dockerfile

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
# shellcheck source-path=SCRIPTDIR
source "${MY_DIR}/build_utils.sh"

if [ "${AUDITWHEEL_POLICY}" != "manylinux2014" ]; then
	echo "Skip libxcrypt installation on ${AUDITWHEEL_POLICY}"
	exit 0
fi

# Install libcrypt.so.1 and libcrypt.so.2
check_var "${LIBXCRYPT_VERSION}"
check_var "${LIBXCRYPT_HASH}"
check_var "${LIBXCRYPT_DOWNLOAD_URL}"
LIBXCRYPT_ROOT="libxcrypt-${LIBXCRYPT_VERSION}"

if [ "${MANYLINUX_DISABLE_CLANG}" -eq 0 ]; then
	# revert to using ld as ldd does not like the version script
	MANYLINUX_LDFLAGS="-fuse-ld=ld ${MANYLINUX_LDFLAGS}"
fi

fetch_source "${LIBXCRYPT_ROOT}.tar.xz" "${LIBXCRYPT_DOWNLOAD_URL}/v${LIBXCRYPT_VERSION}"
check_sha256sum "${LIBXCRYPT_ROOT}.tar.xz" "${LIBXCRYPT_HASH}"
tar xfJ "${LIBXCRYPT_ROOT}.tar.xz"
pushd "${LIBXCRYPT_ROOT}"
DESTDIR=/manylinux-rootfs do_standard_install \
	--disable-obsolete-api \
	--enable-hashes=all \
	--disable-werror
# we also need libcrypt.so.1 with glibc compatibility for system libraries
# c.f https://github.com/pypa/manylinux/issues/305#issuecomment-625902928
make clean > /dev/null
sed -r -i 's/XCRYPT_([0-9.])+/-/g;s/(%chain OW_CRYPT_1.0).*/\1/g' lib/libcrypt.map.in
DESTDIR=/manylinux-rootfs/so.1 do_standard_install \
	--disable-xcrypt-compat-files \
	--enable-obsolete-api=glibc \
	--enable-hashes=all \
	--disable-werror
cp -P /manylinux-rootfs/so.1/usr/local/lib/libcrypt.so.1* /manylinux-rootfs/usr/local/lib/
rm -rf /manylinux-rootfs/so.1
popd
rm -rf "${LIBXCRYPT_ROOT}.tar.xz" "${LIBXCRYPT_ROOT}"

# Strip what we can
strip_ /manylinux-rootfs

# Install
cp -rlf /manylinux-rootfs/* /

# Remove temporary rootfs
rm -rf /manylinux-rootfs

# Delete GLIBC version headers and libraries
rm -rf /usr/include/crypt.h
find /lib* /usr/lib* \( -name 'libcrypt.a' -o -name 'libcrypt.so' -o -name 'libcrypt.so.*' -o -name 'libcrypt-2.*.so' \) -delete
ldconfig

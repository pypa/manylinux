#!/bin/bash
# Top-level build script called from Dockerfile

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
# shellcheck source-path=SCRIPTDIR
source "${MY_DIR}/build_utils.sh"


CERT_IDENTITY=$1
CERT_OIDC_ISSUER=$2
CPYTHON_VERSION=$3
CPYTHON_DOWNLOAD_URL=https://www.python.org/ftp/python


function pyver_dist_dir {
	# Echoes the dist directory name of given pyver, removing alpha/beta prerelease
	# Thus:
	# 3.2.1   -> 3.2.1
	# 3.7.0b4 -> 3.7.0
	echo "$1" | awk -F "." '{printf "%d.%d.%d", $1, $2, $3}'
}

CPYTHON_DIST_DIR=$(pyver_dist_dir "${CPYTHON_VERSION}")
fetch_source "Python-${CPYTHON_VERSION}.tar.xz" "${CPYTHON_DOWNLOAD_URL}/${CPYTHON_DIST_DIR}" skip-hash
fetch_source "Python-${CPYTHON_VERSION}.tar.xz.sigstore" "${CPYTHON_DOWNLOAD_URL}/${CPYTHON_DIST_DIR}" skip-hash
cosign  verify-blob "Python-${CPYTHON_VERSION}.tar.xz" --bundle "Python-${CPYTHON_VERSION}.tar.xz.sigstore" --certificate-identity="${CERT_IDENTITY}" --certificate-oidc-issuer="${CERT_OIDC_ISSUER}"

tar -xJf "Python-${CPYTHON_VERSION}.tar.xz"
pushd "Python-${CPYTHON_VERSION}"
PREFIX="/opt/_internal/cpython-${CPYTHON_VERSION}"
mkdir -p "${PREFIX}/lib"

CFLAGS_NODIST="${MANYLINUX_CFLAGS} ${MANYLINUX_CPPFLAGS}"
LDFLAGS_EXTRA=""
CONFIGURE_ARGS=(--disable-shared --with-ensurepip=no)

if [ "${AUDITWHEEL_ARCH}" == "loongarch64" ]; then
	PATCH_COMMIT="8138f8f7337d95bd098b398d368d4763861f2395"
	PATCH_FILE_SHA256="0db461609cf8385b2859cf16b4e0aa6ef1f51d368e14bd35c4b8b35b8ca00738"
	case "$CPYTHON_VERSION" in
		3.9.*|3.10.*|3.11.*)
			PATCH_FILE="patch-configure-add-loongarch-triplet.patch"
			PATCH_URL="https://github.com/astral-sh/python-build-standalone/raw/${PATCH_COMMIT}/cpython-unix"
			fetch_source "${PATCH_FILE}" "${PATCH_URL}" "${PATCH_FILE_SHA256}"
			patch -p1 < "${PATCH_FILE}"
			rm -f "${PATCH_FILE}"
			;;
	esac
fi

if [ "${4:-}" == "nogil" ]; then
	PREFIX="${PREFIX}-nogil"
	CONFIGURE_ARGS+=(--disable-gil)
fi

if [ "${AUDITWHEEL_POLICY}" == "manylinux2014" ] ; then
	# Python 3.11+
	export TCLTK_LIBS="-L/usr/local/lib -ltk8.6 -ltcl8.6"
fi

if [ "${BASE_POLICY}_${AUDITWHEEL_ARCH}" == "manylinux_armv7l" ]; then
	CONFIGURE_ARGS+=(--build=armv7l-unknown-linux-gnueabihf)
elif [ "${BASE_POLICY}_${AUDITWHEEL_ARCH}" == "musllinux_armv7l" ]; then
	CONFIGURE_ARGS+=(--build=arm-linux-musleabihf)
fi

case "${CPYTHON_VERSION}" in
	3.9.*|3.10.*) sed -i "s|/usr/local/include/sqlite3|/opt/_internal/sqlite3/include|g ; s|sqlite_extra_link_args = ()|sqlite_extra_link_args = ('-Wl,-rpath=/opt/_internal/sqlite3/lib',)|g" setup.py;;
	*) ;;
esac

OPENSSL_PREFIX=$(find /opt/_internal -maxdepth 1 -name 'openssl*')
if [ "${OPENSSL_PREFIX}" != "" ]; then
	CONFIGURE_ARGS+=("--with-openssl=${OPENSSL_PREFIX}")
	case "${CPYTHON_VERSION}" in
		3.9.*) export LDFLAGS_EXTRA="-Wl,-rpath,${OPENSSL_PREFIX}/lib";;
		*) CONFIGURE_ARGS+=(--with-openssl-rpath=auto);;
	esac
fi

# gcc: error: unrecognized command-line option ‘-mno-omit-leaf-frame-pointer’
# https://github.com/pypa/manylinux/issues/1938
# let's patch when building with clang to allow building extensions with gcc
# as we don't want to build without frame pointers altogether which would be
# CONFIGURE_ARGS+=("--without-frame-pointers")
if [ "${MANYLINUX_DISABLE_CLANG}" -eq 0 ] && [ "${MANYLINUX_DISABLE_CLANG_FOR_CPYTHON}" -eq 0 ]; then
	case "${BASE_POLICY}_${AUDITWHEEL_ARCH}" in
	  *_armv7l) PATCH_OMIT_LEAF_FRAME_POINTER=1; PATCH_NO_THUMB=1;;
	  *_loongarch64) PATCH_OMIT_LEAF_FRAME_POINTER=1; PATCH_NO_THUMB=0;;
	  *) PATCH_OMIT_LEAF_FRAME_POINTER=0; PATCH_NO_THUMB=0;;
	esac
	case "${CPYTHON_VERSION}" in
		3.9.*|3.10.*|3.11.*|3.12.*|3.13.*|3.14.*) PATCH_OMIT_LEAF_FRAME_POINTER=0;;
		*) ;;
	esac
	if [ ${PATCH_OMIT_LEAF_FRAME_POINTER} -ne 0 ]; then
		# patch configure when appending "-mno-omit-leaf-frame-pointer"
		sed -i 's/frame_pointer_cflags -mno-omit-leaf-frame-pointer/frame_pointer_cflags/g' ./configure
		# we still want to build the interpreter & stdlib modules with "-mno-omit-leaf-frame-pointer"
		CFLAGS_NODIST="${CFLAGS_NODIST} -mno-omit-leaf-frame-pointer"
	fi
	if [ ${PATCH_NO_THUMB} -ne 0 ]; then
		# patch configure when appending "-mno-thumb"
		sed -i 's/frame_pointer_cflags -mno-thumb/frame_pointer_cflags/g' ./configure
		# we still want to build the interpreter & stdlib modules with "-mno-thumb"
		CFLAGS_NODIST="${CFLAGS_NODIST} -mno-thumb"
	fi
fi

unset _PYTHON_HOST_PLATFORM

# configure with hardening options only for the interpreter & stdlib C extensions
# do not change the default for user built extension (yet?)
./configure \
	CC=gcc \
	CXX=g++ \
	CFLAGS_NODIST="${CFLAGS_NODIST}" \
	LDFLAGS_NODIST="${MANYLINUX_LDFLAGS} ${LDFLAGS_EXTRA}" \
	"--prefix=${PREFIX}" "${CONFIGURE_ARGS[@]}" > /dev/null
make > /dev/null
make install > /dev/null
popd
rm -rf "Python-${CPYTHON_VERSION}" "Python-${CPYTHON_VERSION}.tar.xz" "Python-${CPYTHON_VERSION}.tar.xz.sigstore"

if [ "${OPENSSL_PREFIX}" != "" ]; then
	rm -rf "${OPENSSL_PREFIX:?}/bin" "${OPENSSL_PREFIX}/include" "${OPENSSL_PREFIX}/lib/pkgconfig" "${OPENSSL_PREFIX}/lib/*.so"
fi

# We do not need precompiled .pyc and .pyo files.
clean_pyc "${PREFIX}"

# Strip ELF files found in ${PREFIX}
strip_ "${PREFIX}"

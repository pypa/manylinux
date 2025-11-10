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
fetch_source "Python-${CPYTHON_VERSION}.tar.xz" "${CPYTHON_DOWNLOAD_URL}/${CPYTHON_DIST_DIR}"
fetch_source "Python-${CPYTHON_VERSION}.tar.xz.sigstore" "${CPYTHON_DOWNLOAD_URL}/${CPYTHON_DIST_DIR}"
cosign  verify-blob "Python-${CPYTHON_VERSION}.tar.xz" --bundle "Python-${CPYTHON_VERSION}.tar.xz.sigstore" --certificate-identity="${CERT_IDENTITY}" --certificate-oidc-issuer="${CERT_OIDC_ISSUER}"

tar -xJf "Python-${CPYTHON_VERSION}.tar.xz"
pushd "Python-${CPYTHON_VERSION}"
PREFIX="/opt/_internal/cpython-${CPYTHON_VERSION}"
mkdir -p "${PREFIX}/lib"
LDFLAGS_EXTRA=""
CONFIGURE_ARGS=(--disable-shared --with-ensurepip=no)

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
	3.8.*|3.9.*|3.10.*) sed -i "s|/usr/local/include/sqlite3|/opt/_internal/sqlite3/include|g ; s|sqlite_extra_link_args = ()|sqlite_extra_link_args = ('-Wl,-rpath=/opt/_internal/sqlite3/lib',)|g" setup.py;;
	*) ;;
esac

OPENSSL_PREFIX=$(find /opt/_internal -maxdepth 1 -name 'openssl*')
if [ "${OPENSSL_PREFIX}" != "" ]; then
	CONFIGURE_ARGS+=("--with-openssl=${OPENSSL_PREFIX}")
	case "${CPYTHON_VERSION}" in
		3.8.*|3.9.*) export LDFLAGS_EXTRA="-Wl,-rpath,${OPENSSL_PREFIX}/lib";;
		*) CONFIGURE_ARGS+=(--with-openssl-rpath=auto);;
	esac
fi

unset _PYTHON_HOST_PLATFORM

# configure with hardening options only for the interpreter & stdlib C extensions
# do not change the default for user built extension (yet?)
./configure \
	CC=gcc \
	CXX=g++ \
	CFLAGS_NODIST="${MANYLINUX_CFLAGS} ${MANYLINUX_CPPFLAGS}" \
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

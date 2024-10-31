#!/bin/bash
# Top-level build script called from Dockerfile

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
# shellcheck source-path=SCRIPTDIR
source "${MY_DIR}/build_utils.sh"


CPYTHON_VERSION=$1
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
fetch_source "Python-${CPYTHON_VERSION}.tar.xz.asc" "${CPYTHON_DOWNLOAD_URL}/${CPYTHON_DIST_DIR}"
gpg --import "${MY_DIR}/cpython-pubkeys.txt"
gpg --verify "Python-${CPYTHON_VERSION}.tar.xz.asc"
tar -xJf "Python-${CPYTHON_VERSION}.tar.xz"
pushd "Python-${CPYTHON_VERSION}"
PREFIX="/opt/_internal/cpython-${CPYTHON_VERSION}"
mkdir -p "${PREFIX}/lib"
CFLAGS_EXTRA=""
CONFIGURE_ARGS=(--disable-shared --with-ensurepip=no)

if [ "${2:-}" == "nogil" ]; then
	PREFIX="${PREFIX}-nogil"
	CONFIGURE_ARGS+=(--disable-gil)
fi

if [ "${CPYTHON_VERSION}" == "3.6.15" ]; then
	# https://github.com/python/cpython/issues/89863
	# gcc-12+ uses these 2 flags in -O2 but they were only enabled in -O3 with gcc-11
	CFLAGS_EXTRA="${CFLAGS_EXTRA} -fno-tree-loop-vectorize -fno-tree-slp-vectorize"
fi
if [ "${AUDITWHEEL_POLICY}" == "manylinux2014" ] ; then
	# Python 3.11+
	export TCLTK_LIBS="-ltk8.6 -ltcl8.6"
fi

if [ "${BASE_POLICY}_${AUDITWHEEL_ARCH}" == "manylinux_armv7l" ]; then
	CONFIGURE_ARGS+=(--build=armv7l-unknown-linux-gnueabihf)
elif [ "${BASE_POLICY}_${AUDITWHEEL_ARCH}" == "musllinux_armv7l" ]; then
	CONFIGURE_ARGS+=(--build=arm-linux-musleabihf)
fi

SQLITE_PREFIX=$(find /opt/_internal -maxdepth 1 -name 'sqlite*')
if [ "${SQLITE_PREFIX}" != "" ]; then
	case "${CPYTHON_VERSION}" in
		3.6.*|3.7.*|3.8.*|3.9.*|3.10.*) sed -i "s|/usr/local/include/sqlite3|/opt/_internal/sqlite3/include|g ; s|sqlite_extra_link_args = ()|sqlite_extra_link_args = ('-Wl,--enable-new-dtags,-rpath=/opt/_internal/sqlite3/lib',)|g" setup.py;;
		*) ;;
	esac
fi

OPENSSL_PREFIX=$(find /opt/_internal -maxdepth 1 -name 'openssl*')
if [ "${OPENSSL_PREFIX}" != "" ]; then
	CONFIGURE_ARGS+=("--with-openssl=${OPENSSL_PREFIX}")
	case "${CPYTHON_VERSION}" in
		3.8.*|3.9.*) export LD_RUN_PATH=${OPENSSL_PREFIX}/lib;;
		*) CONFIGURE_ARGS+=(--with-openssl-rpath=auto);;
	esac
fi

unset _PYTHON_HOST_PLATFORM

if [ "${AUDITWHEEL_ARCH}" == "x86_64" ] && echo | gcc -S -x c -v - 2>&1 | grep 'march=x86-64-v' > /dev/null; then
	export EXTRA_CFLAGS="-mtune=generic -march=x86-64"
fi

# configure with hardening options only for the interpreter & stdlib C extensions
# do not change the default for user built extension (yet?)
./configure \
	CFLAGS_NODIST="${MANYLINUX_CFLAGS} ${MANYLINUX_CPPFLAGS} ${CFLAGS_EXTRA}" \
	LDFLAGS_NODIST="${MANYLINUX_LDFLAGS}" \
	"--prefix=${PREFIX}" "${CONFIGURE_ARGS[@]}" > /dev/null
make > /dev/null
make install > /dev/null
popd
rm -rf "Python-${CPYTHON_VERSION}" "Python-${CPYTHON_VERSION}.tgz" "Python-${CPYTHON_VERSION}.tgz.asc"

if [ "${OPENSSL_PREFIX}" != "" ]; then
	rm -rf "${OPENSSL_PREFIX:?}/bin" "${OPENSSL_PREFIX}/include" "${OPENSSL_PREFIX}/lib/pkgconfig" "${OPENSSL_PREFIX}/lib/*.so"
fi

# We do not need precompiled .pyc and .pyo files.
clean_pyc "${PREFIX}"

# Strip ELF files found in ${PREFIX}
strip_ "${PREFIX}"

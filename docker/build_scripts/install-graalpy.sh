#!/bin/bash

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
source $MY_DIR/build_utils.sh

if [ "${BASE_POLICY}" == "musllinux" ]; then
	echo "Skip GraalPy build on musllinux"
	exit 0
fi

PYTHON_VERSION=$1
VERSION_PREFIX=$2
GRAALPY_VERSION=$3
ARCHIVE_PREFIX=$4
GRAALPY_DOWNLOAD_URL=https://github.com/oracle/graalpython/releases/download/${VERSION_PREFIX}-${GRAALPY_VERSION}/
# graal-23.0.0/graalpython-23.0.0-linux-amd64.tar.gz


function get_shortdir {
    local exe=$1
    $exe -c 'import sys; print(sys.implementation.cache_tag)'
}


mkdir -p /tmp
cd /tmp

case ${AUDITWHEEL_ARCH} in
	x86_64) GRAALPY_ARCH=amd64;;
	aarch64) GRAALPY_ARCH=aarch64;;
	*) echo "No PyPy for ${AUDITWHEEL_ARCH}"; exit 0;;
esac

EXPAND_NAME=graalpy-${GRAALPY_VERSION}-linux-${GRAALPY_ARCH}
TMPDIR=/tmp/${EXPAND_NAME}
TARBALL=graalpython-${GRAALPY_VERSION}-linux-${GRAALPY_ARCH}.tar.gz
PREFIX="/opt/_internal"

mkdir -p ${PREFIX}

fetch_source ${TARBALL} ${GRAALPY_DOWNLOAD_URL}

# We only want to check the current tarball sha256sum
grep " ${TARBALL}\$" ${MY_DIR}/graalpy.sha256 > ${TARBALL}.sha256
# then check sha256 sum
sha256sum -c ${TARBALL}.sha256

tar -xf ${TARBALL}

# rename the directory to something shorter like graalpy230-310
PREFIX=${PREFIX}/$(get_shortdir ${TMPDIR}/bin/graalpy)
mv ${TMPDIR} ${PREFIX}

# add a generic "python" symlink
if [ ! -f "${PREFIX}/bin/python" ]; then
	ln -s graalpy ${PREFIX}/bin/python
fi

# We do not need precompiled .pyc and .pyo files.
clean_pyc ${PREFIX}

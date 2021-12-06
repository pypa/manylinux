#!/bin/bash

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
source $MY_DIR/build_utils.sh

if [ "${BASE_POLICY}" == "musllinux" ]; then
	echo "Skip Pyston build on musllinux"
	exit 0
elif [ "${AUDITWHEEL_POLICY}" == "manylinux2010" ]; then
	echo "Skip Pyston build on manylinux2010 - glibc is too old"
	exit 0
fi

PYTHON_VERSION=$1
PYSTON_VERSION=$2
PYSTON_DOWNLOAD_URL=https://github.com/pyston/pyston/releases/download/pyston_${PYSTON_VERSION}


function get_shortdir {
	local exe=$1
	$exe -c 'import sys; print("pyston%d.%d-%d.%d.%d" % (sys.version_info[:2]+sys.pyston_version_info[:3]))'
}


mkdir -p /tmp
cd /tmp

case ${AUDITWHEEL_ARCH} in
	x86_64) PYSTON_ARCH=linux64;;
	*) echo "No Pyston for ${AUDITWHEEL_ARCH}"; exit 0;;
esac

# in v2.3.1 the pyston team found a bug in the portable release package and had to upload a new version with suffix _v2
PYSTON_TARBALL_VERSION=
case ${PYSTON_VERSION} in
	2.3.1) PYSTON_TARBALL_VERSION=_v2;;
	*);;
esac

TARBALL=pyston_${PYSTON_VERSION}_portable${PYSTON_TARBALL_VERSION}.tar.gz
TMPDIR=/tmp/pyston_${PYSTON_VERSION}
PREFIX="/opt/_internal"

mkdir -p ${PREFIX}

fetch_source ${TARBALL} ${PYSTON_DOWNLOAD_URL}

# We only want to check the current tarball sha256sum
grep " ${TARBALL}\$" ${MY_DIR}/pyston.sha256 > ${TARBALL}.sha256
# then check sha256 sum
sha256sum -c ${TARBALL}.sha256

tar -xf ${TARBALL}

# rename the directory to something shorter like pyston3.8-2.3.1
PREFIX=${PREFIX}/$(get_shortdir ${TMPDIR}/bin/pyston)
mv ${TMPDIR} ${PREFIX}

# add a generic "python" symlink
if [ ! -f "${PREFIX}/bin/python" ]; then
	ln -s pyston ${PREFIX}/bin/python
fi

# We do not need the Python test suites
find ${PREFIX} -depth \( -type d -a -name test -o -name tests \) | xargs rm -rf

# Remove pip because Pystons bundled pip does not create 'pip' and 'pip3'
# finalize.sh will run ensurepip to install it correctly
${PREFIX}/bin/pyston -m pip uninstall -y pip

# We do not need precompiled .pyc and .pyo files.
clean_pyc ${PREFIX}

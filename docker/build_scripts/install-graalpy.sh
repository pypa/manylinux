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

case ${AUDITWHEEL_ARCH} in
	x86_64) GRAALPY_ARCH=amd64;;
	aarch64) GRAALPY_ARCH=aarch64;;
	*) echo "No GraalPy for ${AUDITWHEEL_ARCH}"; exit 0;;
esac

PYTHON_VERSION=$1
VERSION_PREFIX=$2
GRAALPY_VERSION=$3
ARCHIVE_PREFIX=$4
GRAALPY_DOWNLOAD_URL=https://github.com/oracle/graalpython/releases/download/${VERSION_PREFIX}-${GRAALPY_VERSION}/ # e.g. graal-23.0.0/graalpython-23.0.0-linux-amd64.tar.gz
TMPDIR=/tmp/
TARBALL=graalpython-${GRAALPY_VERSION}-linux-${GRAALPY_ARCH}.tar.gz
TARBALL_SHA=`grep " ${TARBALL}\$" ${MY_DIR}/graalpy.sha256`
PREFIX="/opt/_internal/graalpy-${GRAALPY_VERSION}"

# create a download script that will download and extract graalpy. we leave
# this script in the image to avoid the large distribution to use up space in
# the default image.
mkdir -p ${PREFIX}
cat <<EOF> ${PREFIX}/install-graalpy.sh
#!/bin/bash
set -exuo pipefail
mkdir -p ${PREFIX}
mkdir -p ${TMPDIR}
curl -fsSL -o "${TMPDIR}/${TARBALL}" "${GRAALPY_DOWNLOAD_URL}/${TARBALL}"
cd ${TMPDIR}
echo "${TARBALL_SHA}" | sha256sum -c
tar -xf "${TMPDIR}/${TARBALL}" --overwrite --strip-components=1 -C "${PREFIX}"
rm -f "${TMPDIR}/${TARBALL}"
EOF

# call the download script right now.
chmod +x ${PREFIX}/install-graalpy.sh
${PREFIX}/install-graalpy.sh

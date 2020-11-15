#!/bin/bash
# Top-level build script called from Dockerfile

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
source $MY_DIR/build_utils.sh

# Install newest swig
SWIG_VERSION=4.0.2
SWIG_HASH=d53be9730d8d58a16bf0cbd1f8ac0c0c3e1090573168bfa151b01eb47fa906fc
SWIG_DOWNLOAD_URL=https://sourceforge.net/projects/swig/files/swig/swig-${SWIG_VERSION}

PCRE_VERSION=8.44
PCRE_HASH=aecafd4af3bd0f3935721af77b889d9024b2e01d96b58471bd91a3063fb47728
PCRE_DOWNLOAD_URL=https://ftp.pcre.org/pub/pcre

fetch_source swig-${SWIG_VERSION}.tar.gz ${SWIG_DOWNLOAD_URL}/
check_sha256sum swig-${SWIG_VERSION}.tar.gz ${SWIG_HASH}
tar -xzf swig-${SWIG_VERSION}.tar.gz
pushd swig-${SWIG_VERSION}
fetch_source pcre-${PCRE_VERSION}.tar.gz ${PCRE_DOWNLOAD_URL}/
check_sha256sum pcre-${PCRE_VERSION}.tar.gz ${PCRE_HASH}
./Tools/pcre-build.sh
./configure
make -j$(nproc)
make install DESTDIR=/manylinux/swig
popd
rm -rf swig-${SWIG_VERSION}

# Strip what we can
strip_ /manylinux/swig

# Install
cp -rf /manylinux/swig/* /


swig -version

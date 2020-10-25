#!/bin/bash
# Top-level build script called from Dockerfile

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
source $MY_DIR/build_utils.sh

# Install newest libtool
GIT_ROOT=git-2.29.1
GIT_HASH=728845a66103d8d1572a656123c2c09d7aa4c0ab8f4c3dc3911e14e18c85ee67
GIT_DOWNLOAD_URL=https://www.kernel.org/pub/software/scm/git


fetch_source ${GIT_ROOT}.tar.gz ${GIT_DOWNLOAD_URL}
check_sha256sum ${GIT_ROOT}.tar.gz ${GIT_HASH}
tar -xzf ${GIT_ROOT}.tar.gz
pushd ${GIT_ROOT}
make -j$(nproc) install prefix=/usr/local NO_GETTEXT=1 NO_TCLTK=1 DESTDIR=/manylinux/git
popd
rm -rf ${GIT_ROOT} ${GIT_ROOT}.tar.gz


# Strip what we can
strip_ /manylinux/git

# Install
cp -rf /manylinux/git/* /

git version

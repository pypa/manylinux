#!/bin/bash
# Top-level build script called from Dockerfile

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
source $MY_DIR/build_utils.sh

# Install newest libtool
GIT_ROOT=git-2.29.2
GIT_HASH=869a121e1d75e4c28213df03d204156a17f02fce2dc77be9795b327830f54195
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

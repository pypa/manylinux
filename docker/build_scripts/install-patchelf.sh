#!/bin/bash
# Top-level build script called from Dockerfile

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
source $MY_DIR/build_utils.sh

# Install patchelf (latest with unreleased bug fixes) and apply our patches
check_var ${PATCHELF_VERSION}
check_var ${PATCHELF_HASH}
check_var ${PATCHELF_DOWNLOAD_URL}
fetch_source ${PATCHELF_VERSION}.tar.gz ${PATCHELF_DOWNLOAD_URL}
check_sha256sum ${PATCHELF_VERSION}.tar.gz ${PATCHELF_HASH}
tar -xzf ${PATCHELF_VERSION}.tar.gz
pushd patchelf-${PATCHELF_VERSION}
./bootstrap.sh
do_standard_install
popd
rm -rf ${PATCHELF_VERSION}.tar.gz patchelf-${PATCHELF_VERSION}


patchelf --version

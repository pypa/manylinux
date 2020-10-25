#!/bin/bash
# Top-level build script called from Dockerfile

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
source $MY_DIR/build_utils.sh

# Install patchelf (latest with unreleased bug fixes) and apply our patches
PATCHELF_VERSION=0.12
PATCHELF_HASH=3dca33fb862213b3541350e1da262249959595903f559eae0fbc68966e9c3f56


curl -fsSL -o patchelf.tar.gz https://github.com/NixOS/patchelf/archive/$PATCHELF_VERSION.tar.gz
check_sha256sum patchelf.tar.gz $PATCHELF_HASH
tar -xzf patchelf.tar.gz
pushd patchelf-$PATCHELF_VERSION
./bootstrap.sh
do_standard_install
popd
rm -rf patchelf.tar.gz patchelf-$PATCHELF_VERSION


patchelf --version

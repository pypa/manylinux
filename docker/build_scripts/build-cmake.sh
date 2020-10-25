#!/bin/bash
# Top-level build script called from Dockerfile

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
source $MY_DIR/build_utils.sh

# Install newest cmake
CMAKE_VERSION=3.18.4
CMAKE_HASH=597c61358e6a92ecbfad42a9b5321ddd801fc7e7eca08441307c9138382d4f77
CMAKE_DOWNLOAD_URL=https://github.com/Kitware/CMake/releases/download


fetch_source cmake-${CMAKE_VERSION}.tar.gz ${CMAKE_DOWNLOAD_URL}/v${CMAKE_VERSION}
check_sha256sum cmake-${CMAKE_VERSION}.tar.gz ${CMAKE_HASH}
tar -xzf cmake-${CMAKE_VERSION}.tar.gz
pushd cmake-${CMAKE_VERSION}
./bootstrap --system-curl --parallel=$(nproc)
make -j$(nproc)
make install DESTDIR=/manylinux/cmake
popd
rm -rf cmake-${CMAKE_VERSION}

# remove help
rm -rf /manylinux/cmake/usr/local/share/cmake-*/Help

# Strip what we can
strip_ /manylinux/cmake

# Install
cp -rf /manylinux/cmake/* /


cmake --version

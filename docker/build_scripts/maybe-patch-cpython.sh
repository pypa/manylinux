#!/bin/bash
# Patch applying script called from build-cpython.sh

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

PATCHES_DIR=$MY_DIR/cpython-patches

CPYTHON_VERSION=$1
CPYTHON_SRC_DIR=Python-${CPYTHON_VERSION}

if [[ "${CPYTHON_VERSION}" == 3.6* ]]; then
  patch -s -p0 -d "${CPYTHON_SRC_DIR}" < $PATCHES_DIR/bpo-44751-cp36.diff
fi

if [[ "${CPYTHON_VERSION}" == 3.7* ]]; then
  patch -s -p0 -d "${CPYTHON_SRC_DIR}" < $PATCHES_DIR/bpo-44751-cp37.diff
fi

if [[ "${CPYTHON_VERSION}" == 3.8* ]]; then
  patch -s -p0 -d "${CPYTHON_SRC_DIR}" < $PATCHES_DIR/bpo-44751-cp38.diff
fi

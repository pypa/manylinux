#!/bin/bash

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")


for PYTHON in /opt/python/*/bin/python; do
	# Smoke test to make sure that our Pythons work, and do indeed detect as
	# being manylinux compatible:
	$PYTHON $MY_DIR/manylinux-check.py ${AUDITWHEEL_POLICY} ${AUDITWHEEL_ARCH}
	# Make sure that SSL cert checking works
	$PYTHON $MY_DIR/ssl-check.py
done

# minimal tests for tools that should be present
autoconf --version
automake --version
libtoolize --version
patchelf --version
git --version
cmake --version
swig -version

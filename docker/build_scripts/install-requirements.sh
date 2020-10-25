#!/bin/bash
# Top-level build script called from Dockerfile

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
source $MY_DIR/build_utils.sh


for PREFIX in $(find /opt/_internal/ -mindepth 1 -maxdepth 1 -name 'cpython*'); do
	# Since we fall back on a canned copy of pip, we might not have
	# the latest pip and friends. Upgrade them to make sure.
	${PREFIX}/bin/pip install -U --require-hashes -r ${MY_DIR}/requirements.txt
done

# We do not need precompiled .pyc and .pyo files.
clean_pyc ${PREFIX}

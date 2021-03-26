#!/bin/bash

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

if [ "${AUDITWHEEL_POLICY}" == "manylinux2010" ] || [ "${AUDITWHEEL_POLICY}" == "manylinux2014" ]; then
	PACKAGE_MANAGER=yum
elif [ "${AUDITWHEEL_POLICY}" == "manylinux_2_24" ]; then
	export DEBIAN_FRONTEND=noninteractive
	PACKAGE_MANAGER=apt
	apt-get update -qq
else
	echo "Unsupported policy: '${AUDITWHEEL_POLICY}'"
	exit 1
fi


for PYTHON in /opt/python/*/bin/python; do
	# Smoke test to make sure that our Pythons work, and do indeed detect as
	# being manylinux compatible:
	$PYTHON $MY_DIR/manylinux-check.py ${AUDITWHEEL_POLICY} ${AUDITWHEEL_ARCH}
	# Make sure that SSL cert checking works
	$PYTHON $MY_DIR/ssl-check.py
	# Make sure sqlite3 module can be loaded properly and is the manylinux version one
	# c.f. https://github.com/pypa/manylinux/issues/1030
	$PYTHON -c 'import sqlite3; print(sqlite3.sqlite_version); assert sqlite3.sqlite_version_info[0:2] >= (3, 34)'
done

# minimal tests for tools that should be present
autoconf --version
automake --version
libtoolize --version
patchelf --version
git --version
cmake --version
swig -version
sqlite3 --version

# check libcrypt.so.1 can be loaded by some system packages,
# as LD_LIBRARY_PATH might not be enough.
# c.f. https://github.com/pypa/manylinux/issues/1022
if [ "${PACKAGE_MANAGER}" == "yum" ]; then
	yum -y install openssh-clients
elif [ "${PACKAGE_MANAGER}" == "apt" ]; then
	apt-get install -qq -y --no-install-recommends openssh-client
else
	echo "Unsupported package manager: '${PACKAGE_MANAGER}'"
	exit 1
fi
eval "$(ssh-agent)"
eval "$(ssh-agent -k)"

# compilation tests, intended to ensure appropriate headers, pkg_config, etc.
# are available for downstream compile against installed tools
source_dir="${MY_DIR}/ctest"
build_dir="$(mktemp -d)"
cmake -S "${source_dir}" -B "${build_dir}"
cmake --build "${build_dir}"
(cd "${build_dir}"; ctest --output-on-failure)

# final report
echo "run_tests successful!"

#!/bin/bash

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

if [ "${AUDITWHEEL_POLICY}" == "manylinux2014" ]; then
	PACKAGE_MANAGER=yum
elif [ "${AUDITWHEEL_POLICY:0:10}" == "musllinux_" ]; then
	PACKAGE_MANAGER=apk
elif [ "${AUDITWHEEL_POLICY}" == "manylinux_2_28" ] || [ "${AUDITWHEEL_POLICY}" == "manylinux_2_34" ]; then
	PACKAGE_MANAGER=dnf
else
	echo "Unsupported policy: '${AUDITWHEEL_POLICY}'"
	exit 1
fi

if [ "${AUDITWHEEL_POLICY:0:10}" == "musllinux_" ]; then
	EXPECTED_PYTHON_COUNT=9
	EXPECTED_PYTHON_COUNT_ALL=9
else
	if [ "${AUDITWHEEL_ARCH}" == "x86_64" ] || [ "${AUDITWHEEL_ARCH}" == "aarch64" ]; then
		EXPECTED_PYTHON_COUNT=11
		EXPECTED_PYTHON_COUNT_ALL=14
	elif [ "${AUDITWHEEL_ARCH}" == "i686" ]; then
		EXPECTED_PYTHON_COUNT=11
		EXPECTED_PYTHON_COUNT_ALL=13
	else
		EXPECTED_PYTHON_COUNT=9
		EXPECTED_PYTHON_COUNT_ALL=9
	fi
fi
PYTHON_COUNT=$(manylinux-interpreters list --installed | wc -l)
if [ ${EXPECTED_PYTHON_COUNT} -ne ${PYTHON_COUNT} ]; then
	echo "unexpected number of default python installations: ${PYTHON_COUNT}, expecting ${EXPECTED_PYTHON_COUNT}"
	manylinux-interpreters list --installed
	exit 1
fi
PYTHON_COUNT_ALL=$(manylinux-interpreters list | wc -l)
if [ ${EXPECTED_PYTHON_COUNT_ALL} -ne ${PYTHON_COUNT_ALL} ]; then
	echo "unexpected number of overall python installations: ${PYTHON_COUNT_ALL}, expecting ${EXPECTED_PYTHON_COUNT_ALL}"
	manylinux-interpreters list
	exit 1
fi
manylinux-interpreters ensure-all
PYTHON_COUNT=$(manylinux-interpreters list --installed | wc -l)
if [ ${EXPECTED_PYTHON_COUNT_ALL} -ne ${PYTHON_COUNT} ]; then
	echo "unexpected number of python installations after 'manylinux-python ensure-all': ${PYTHON_COUNT}, expecting ${EXPECTED_PYTHON_COUNT_ALL}"
	manylinux-interpreters list --installed
	exit 1
fi

PYTHON_COUNT=0
for PYTHON in /opt/python/*/bin/python; do
	# Smoke test to make sure that our Pythons work, and do indeed detect as
	# being manylinux compatible:
	$PYTHON $MY_DIR/manylinux-check.py ${AUDITWHEEL_POLICY} ${AUDITWHEEL_ARCH}
	# Make sure that SSL cert checking works
	$PYTHON $MY_DIR/ssl-check.py
	IMPLEMENTATION=$(${PYTHON} -c "import sys; print(sys.implementation.name)")
	PYVERS=$(${PYTHON} -c "import sys; print('.'.join(map(str, sys.version_info[:2])))")
	PY_GIL=$(${PYTHON} -c "import sysconfig; print('t' if sysconfig.get_config_vars().get('Py_GIL_DISABLED', 0) else '')")
	if [ "${IMPLEMENTATION}" == "cpython" ]; then
		# Make sure sqlite3 module can be loaded properly and is the manylinux version one
		# c.f. https://github.com/pypa/manylinux/issues/1030
		$PYTHON -c 'import sqlite3; print(sqlite3.sqlite_version); assert sqlite3.sqlite_version_info[0:2] >= (3, 34)'
		# Make sure tkinter module can be loaded properly
		$PYTHON -c 'import tkinter; print(tkinter.TkVersion); assert tkinter.TkVersion >= 8.6'
		# cpython shall be available as python
		LINK_VERSION=$(python${PYVERS}${PY_GIL} -VV)
		REAL_VERSION=$(${PYTHON} -VV)
		test "${LINK_VERSION}" = "${REAL_VERSION}"
	fi
	# cpythonX.Y / pypyX.Y shall be available directly in PATH
	LINK_VERSION=$(${IMPLEMENTATION}${PYVERS}${PY_GIL} -VV)
	REAL_VERSION=$(${PYTHON} -VV)
	test "${LINK_VERSION}" = "${REAL_VERSION}"

	# check a simple project can be built
	PY_ABI_TAGS=$(basename $(dirname $(dirname $PYTHON)))
	SRC_DIR=/tmp/forty-two-${PY_ABI_TAGS}
	DIST_DIR=/tmp/dist-${PY_ABI_TAGS}
	cp -rf ${MY_DIR}/forty-two ${SRC_DIR}
	EXPECTED_WHEEL_NAME=forty_two-0.1.0-${PY_ABI_TAGS}-linux_${AUDITWHEEL_ARCH}.whl
	${PYTHON} -m build -w -o ${DIST_DIR} ${SRC_DIR}
	if [ ! -f ${DIST_DIR}/${EXPECTED_WHEEL_NAME} ]; then
		echo "unexcpected wheel built: '$(basename $(find ${DIST_DIR} -name '*.whl'))' instead  of '${EXPECTED_WHEEL_NAME}'"
		exit 1
	fi
	auditwheel repair --only-plat -w ${DIST_DIR} ${DIST_DIR}/${EXPECTED_WHEEL_NAME}
	REPAIRED_WHEEL=$(find ${DIST_DIR} -name "forty_two-0.1.0-${PY_ABI_TAGS}-*${AUDITWHEEL_POLICY}_${AUDITWHEEL_ARCH}*.whl")
	if [ ! -f "${REPAIRED_WHEEL}" ]; then
		echo "invalid repaired wheel name"
		exit 1
	fi
	${PYTHON} -m pip install ${REPAIRED_WHEEL}
	if [ "$(${PYTHON} -c 'import forty_two; print(forty_two.answer())')" != "42" ]; then
		echo "invalid answer, expecting 42"
		exit 1
	fi
	if [ "${PYVERS}" != "3.6" ] && [ "${PYVERS}" != "3.7" ] && [ "${IMPLEMENTATION}" != "graalpy" ] && [ "${AUDITWHEEL_POLICY:0:9}_${AUDITWHEEL_ARCH}" != "musllinux_s390x" ] && [ "${AUDITWHEEL_ARCH}" != "ppc64le" ]; then
		# no uv on musllinux s390x
		# FIXME, ppc64le test fails on Travis CI but works with qemu
		UV_PYTHON=/tmp/uv-test-${IMPLEMENTATION}${PYVERS}/bin/python
		uv venv --python ${PYTHON} /tmp/uv-test-${IMPLEMENTATION}${PYVERS}
		uv pip install --python ${UV_PYTHON} ${REPAIRED_WHEEL}
		if [ "$(${UV_PYTHON} -c 'import forty_two; print(forty_two.answer())')" != "42" ]; then
			echo "invalid answer, expecting 42"
			exit 1
		fi
	fi
	PYTHON_COUNT=$(( $PYTHON_COUNT + 1 ))
done
if [ ${EXPECTED_PYTHON_COUNT_ALL} -ne ${PYTHON_COUNT} ]; then
	echo "all python installations were not tested: ${PYTHON_COUNT}, expecting ${EXPECTED_PYTHON_COUNT_ALL}"
	ls /opt/python
	exit 1
fi

# we stopped installing sqlite3 in manylinux_2_34
SQLITE_PREFIX=$(find /opt/_internal -maxdepth 1 -name 'sqlite*')

# minimal tests for tools that should be present
auditwheel --version
autoconf --version
automake --version
libtoolize --version
patchelf --version
git --version
cmake --version
swig -version
if [ "${SQLITE_PREFIX}" == "" ]; then
	sqlite3 --version
fi
pipx run nox --version
pipx install --pip-args='--no-python-version-warning --no-input' nox
nox --version
tar --version | grep "GNU tar"

# check libcrypt.so.1 can be loaded by some system packages,
# as LD_LIBRARY_PATH might not be enough.
# c.f. https://github.com/pypa/manylinux/issues/1022
if [ "${PACKAGE_MANAGER}" == "yum" ]; then
	yum -y install openssh-clients
elif [ "${PACKAGE_MANAGER}" == "apk" ]; then
	apk add --no-cache openssh-client
elif [ "${PACKAGE_MANAGER}" == "dnf" ]; then
	dnf -y install --allowerasing openssh-clients
else
	echo "Unsupported package manager: '${PACKAGE_MANAGER}'"
	exit 1
fi
eval "$(ssh-agent)"
eval "$(ssh-agent -k)"

if [ "${SQLITE_PREFIX}" == "" ]; then
	# compilation tests, intended to ensure appropriate headers, pkg_config, etc.
	# are available for downstream compile against installed tools
	source_dir="${MY_DIR}/ctest"
	build_dir="$(mktemp -d)"
	cmake -S "${source_dir}" -B "${build_dir}"
	cmake --build "${build_dir}"
	(cd "${build_dir}"; ctest --output-on-failure)
fi

# https://github.com/pypa/manylinux/issues/1060
# wrong /usr/local/man symlink
if [ -L /usr/local/man ]; then
	test -d /usr/local/man
fi

# final report
echo "run_tests successful!"

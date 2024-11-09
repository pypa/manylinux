#!/bin/bash

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

if [ "${AUDITWHEEL_POLICY:0:10}" == "musllinux_" ]; then
	EXPECTED_PYTHON_COUNT=9
	EXPECTED_PYTHON_COUNT_ALL=9
else
	if [ "${AUDITWHEEL_ARCH}" == "x86_64" ] || [ "${AUDITWHEEL_ARCH}" == "aarch64" ]; then
		EXPECTED_PYTHON_COUNT=10
		EXPECTED_PYTHON_COUNT_ALL=14
	elif [ "${AUDITWHEEL_ARCH}" == "i686" ]; then
		EXPECTED_PYTHON_COUNT=10
		EXPECTED_PYTHON_COUNT_ALL=13
	else
		EXPECTED_PYTHON_COUNT=9
		EXPECTED_PYTHON_COUNT_ALL=9
	fi
fi

# the following environment variable allows other manylinux-like projects to run
# the same tests as manylinux without the same number of CPython installations
if [ "${ADJUST_CPYTHON_COUNT:-}" != "" ]; then
	EXPECTED_PYTHON_COUNT=$(( ${EXPECTED_PYTHON_COUNT} ${ADJUST_CPYTHON_COUNT} ))
	EXPECTED_PYTHON_COUNT_ALL=$(( ${EXPECTED_PYTHON_COUNT_ALL} ${ADJUST_CPYTHON_COUNT} ))
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
		$PYTHON -c 'import sqlite3; print(sqlite3.sqlite_version); assert sqlite3.sqlite_version_info[0:2] >= (3, 31)'
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
	if [ "${PYVERS}" != "3.6" ] && [ "${PYVERS}" != "3.7" ] && [ "${IMPLEMENTATION}" != "graalpy" ] && [ "${AUDITWHEEL_POLICY:0:9}_${AUDITWHEEL_ARCH}" != "musllinux_s390x" ] && [ "${AUDITWHEEL_ARCH}" != "riscv64" ]; then
		# no uv on musllinux s390x
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

# minimal tests for tools that should be present
auditwheel --version
autoconf --version
automake --version
libtoolize --version
patchelf --version
git --version
cmake --version
swig -version
pipx run nox --version
pipx install --pip-args='--no-python-version-warning --no-input' nox
nox --version
tar --version | grep "GNU tar"
# we stopped installing sqlite3 after manylinux_2_28 / musllinux_1_2
if [ "${AUDITWHEEL_POLICY}" == "manylinux2014" ] || [ "${AUDITWHEEL_POLICY}" == "manylinux_2_28" ] || [ "${AUDITWHEEL_POLICY}" == "musllinux_1_2" ]; then
	sqlite3 --version
fi

# check libcrypt.so.1 can be loaded by some system packages,
# as LD_LIBRARY_PATH might not be enough.
# c.f. https://github.com/pypa/manylinux/issues/1022
if [ "${AUDITWHEEL_POLICY}" == "manylinux2014" ]; then
	yum -y install openssh-clients
	eval "$(ssh-agent)"
	eval "$(ssh-agent -k)"
fi

if [ "${AUDITWHEEL_POLICY}" == "manylinux2014" ] || [ "${AUDITWHEEL_POLICY}" == "manylinux_2_28" ] || [ "${AUDITWHEEL_POLICY}" == "musllinux_1_2" ]; then
	# sqlite compilation tests, intended to ensure appropriate headers, pkg_config, etc.
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

# check the default shell is /bin/bash
test "$SHELL" = "/bin/bash"

# final report
echo "run_tests successful!"

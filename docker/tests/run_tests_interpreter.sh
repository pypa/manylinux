#!/bin/bash

# Stop at any error, show all commands
set -euo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

PYTHON_PREFIX=$1
PYTHON=${PYTHON_PREFIX}/bin/python
PYTHON_DIRNAME=$(basename "${PYTHON_PREFIX}")

exec > >(trap "" INT TERM; sed "s/^/${PYTHON_DIRNAME}: /")
exec 2> >(trap "" INT TERM; sed "s/^/${PYTHON_DIRNAME}: /" >&2)

set -x

TMP_CWD=$(mktemp -d)
pushd "${TMP_CWD}"

# Smoke test to make sure that our Pythons work, and do indeed detect as
# being manylinux compatible:
$PYTHON "${MY_DIR}/manylinux-check.py" "${AUDITWHEEL_POLICY}" "${AUDITWHEEL_ARCH}"
# Make sure that SSL cert checking works
$PYTHON "${MY_DIR}/ssl-check.py"
IMPLEMENTATION=$(${PYTHON} -c "import sys; print(sys.implementation.name)")
PYVERS=$(${PYTHON} -c "import sys; print('.'.join(map(str, sys.version_info[:2])))")
PY_GIL=$(${PYTHON} -c "import sysconfig; print('t' if sysconfig.get_config_vars().get('Py_GIL_DISABLED', 0) else '')")
PY_ABI_TAGS=${PYTHON_DIRNAME}
if [ "${IMPLEMENTATION}" == "cpython" ]; then
	# check all modules can be loaded
	$PYTHON -Wignore "${MY_DIR}/modules-check.py"
	# cpython shall be available as python
	LINK_VERSION=$("python${PYVERS}${PY_GIL}" -VV)
	REAL_VERSION=$(${PYTHON} -VV)
	test "${LINK_VERSION}" = "${REAL_VERSION}"
fi
# cpythonX.Y / pypyX.Y shall be available directly in PATH
# pypy3.11 exists with 2 different ABIs, only link pp311-pypy311_pp73 for now
if [[ "${PY_ABI_TAGS}" != "pp311-pypy311_pp80" ]]; then
	LINK_VERSION=$("${IMPLEMENTATION}${PYVERS}${PY_GIL}" -VV)
	REAL_VERSION=$(${PYTHON} -VV)
	test "${LINK_VERSION}" = "${REAL_VERSION}"
fi

# check a simple project can be built
SRC_DIR=${TMP_CWD}/forty-two-${PY_ABI_TAGS}
DIST_DIR=${TMP_CWD}/dist-${PY_ABI_TAGS}
cp -rf "${MY_DIR}/forty-two" "${SRC_DIR}"
EXPECTED_WHEEL_NAME=forty_two-0.1.0-${PY_ABI_TAGS}-linux_${AUDITWHEEL_ARCH}.whl
${PYTHON} -m build -w -o "${DIST_DIR}" "${SRC_DIR}"
if [ ! -f "${DIST_DIR}/${EXPECTED_WHEEL_NAME}" ]; then
	echo "unexpected wheel built: '$(find "${DIST_DIR}" -name '*.whl' -exec basename '{}' \; -quit)' instead  of '${EXPECTED_WHEEL_NAME}'"
	exit 1
fi
AUDITWHEEL_LD_LIBRARY_PATH="${SRC_DIR}/eleven:${SRC_DIR}/ten:${LD_LIBRARY_PATH}"
LD_LIBRARY_PATH="${AUDITWHEEL_LD_LIBRARY_PATH}" auditwheel repair --only-plat -w "${DIST_DIR}" "${DIST_DIR}/${EXPECTED_WHEEL_NAME}"
REPAIRED_WHEEL=$(find "${DIST_DIR}" -name "forty_two-0.1.0-${PY_ABI_TAGS}-*${AUDITWHEEL_POLICY}_${AUDITWHEEL_ARCH}*.whl")
if [ ! -f "${REPAIRED_WHEEL}" ]; then
	echo "invalid repaired wheel name"
	exit 1
fi
${PYTHON} -m pip install "${REPAIRED_WHEEL}"
if [ "$(${PYTHON} -c 'import forty_two; print(forty_two.answer())')" != "42" ]; then
	echo "invalid answer, expecting 42"
	exit 1
fi
if [ "${IMPLEMENTATION}" != "graalpy" ] && [ "${AUDITWHEEL_POLICY:0:9}_${AUDITWHEEL_ARCH}" != "musllinux_ppc64le" ] && [ "${AUDITWHEEL_POLICY:0:9}_${AUDITWHEEL_ARCH}" != "musllinux_s390x" ] && [ "${AUDITWHEEL_ARCH}" != "loongarch64" ]; then
	# no uv on GraalPy, musllinux ppc64le / s390x, or loongarch64
	UV_PYTHON=${TMP_CWD}/uv-test-${PY_ABI_TAGS}/bin/python
	uv venv --python "${PYTHON}" "${TMP_CWD}/uv-test-${PY_ABI_TAGS}"
	uv pip install --python "${UV_PYTHON}" "${REPAIRED_WHEEL}"
	if [ "$(${UV_PYTHON} -c 'import forty_two; print(forty_two.answer())')" != "42" ]; then
		echo "invalid answer, expecting 42"
		exit 1
	fi
fi

popd
rm -rf "${TMP_CWD}"

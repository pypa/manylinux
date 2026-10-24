#!/bin/bash

# Stop at any error, show all commands
set -exuo pipefail

PREFIX=$1

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Some python's install as bin/python3. Make them available as
# bin/python.
if [ -e "${PREFIX}/bin/python3" ] && [ ! -e "${PREFIX}/bin/python" ]; then
	ln -s python3 "${PREFIX}/bin/python"
fi
PY_VER=$("${PREFIX}/bin/python" -c "import sys; print('.'.join(str(v) for v in sys.version_info[:2]))")
PY_IMPL=$("${PREFIX}/bin/python" -c "import sys; print(sys.implementation.name)")
PY_GIL=$("${PREFIX}/bin/python" -c "import sysconfig; print('t' if sysconfig.get_config_vars().get('Py_GIL_DISABLED', 0) else '')")

# disable some pip warnings
export PIP_ROOT_USER_ACTION=ignore
export PIP_DISABLE_PIP_VERSION_CHECK=1
export PIP_NO_WARN_SCRIPT_LOCATION=0

if [ "${PY_IMPL}" == "graalpy" ]; then
	# GraalPy doesn't update pip because it uses a patched version of pip
	"${PREFIX}/bin/python" -m ensurepip --default-pip
	case ${PY_VER} in
		3.11) "${PREFIX}/bin/python" -m pip uninstall -y setuptools;;
	esac
else
	# patch bundled pip & uninstall everything (if pip already installed) & ensurepip
	if [ "${PY_IMPL}" == "cpython" ]; then
		ENSURE_PIP_DIR="${PREFIX}/lib/python${PY_VER}${PY_GIL}/ensurepip"
	else
		ENSURE_PIP_DIR="${PREFIX}/lib/${PY_IMPL}${PY_VER}/ensurepip"
	fi
	rm -f "${ENSURE_PIP_DIR}/_bundled/"pip-*.whl
	PIP_WHEEL=$(find "/opt/_internal/pip-wheels/${PY_VER}" -name 'pip-*.whl')
	cp "${PIP_WHEEL}" "${ENSURE_PIP_DIR}/_bundled/"
	PIP_FNAME=$(basename "${PIP_WHEEL}")
	PIP_VERSION=${PIP_FNAME:4}  # strip "pip-"
	PIP_VERSION=${PIP_VERSION%%-py*}  # remove suffix starting at python tag, assumes it always start with -py
	sed -i "s/^_PIP_VERSION = .*/_PIP_VERSION = \"${PIP_VERSION}\"/g" "${ENSURE_PIP_DIR}/__init__.py"
	if "${PREFIX}/bin/python" -m pip -V &>/dev/null; then
		"${PREFIX}/bin/python" -m pip uninstall -y -r <("${PREFIX}/bin/python" -m pip freeze --all)
	fi
	"${PREFIX}/bin/python" -m ensurepip
	case ${PY_VER} in
		3.9|3.10|3.11) "${PREFIX}/bin/python" -m pip uninstall -y setuptools;;
	esac
fi

# Install pinned packages for this python version.
"${PREFIX}/bin/python" -m pip install -U --require-hashes -r "${MY_DIR}/requirements/${PY_VER}/packages.txt"

if [ -e "${PREFIX}/bin/pip3" ] && [ ! -e "${PREFIX}/bin/pip" ]; then
	ln -s pip3 "${PREFIX}/bin/pip"
fi
# Create a symlink to PREFIX using the ABI_TAG in /opt/python/
ABI_TAG=$("${PREFIX}/bin/python" "${MY_DIR}/python-tag-abi-tag.py")
ln -s "${PREFIX}" "/opt/python/${ABI_TAG}"

# Make versioned python commands available directly in environment.
# pypy3.11 exists with 2 different ABIs, only link pp311-pypy311_pp73 for now
if [[ "${ABI_TAG}" == "pp311-pypy311_pp80" ]]; then
	exit 0
fi
# Don't use symlinks: c.f. https://github.com/python/cpython/issues/106045
cat <<EOF > "/usr/local/bin/${PY_IMPL}${PY_VER}${PY_GIL}"
#!/bin/sh
exec "/opt/python/${ABI_TAG}/bin/python" "\$@"
EOF
chmod +x "/usr/local/bin/${PY_IMPL}${PY_VER}${PY_GIL}"
if [[ "${PY_IMPL}" == "cpython" ]]; then
	ln -s "${PY_IMPL}${PY_VER}${PY_GIL}" "/usr/local/bin/python${PY_VER}${PY_GIL}"
fi

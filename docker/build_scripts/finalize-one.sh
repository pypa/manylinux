#!/bin/bash

# Stop at any error, show all commands
set -exuo pipefail

PREFIX=$1

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Some python's install as bin/python3. Make them available as
# bin/python.
if [ -e ${PREFIX}/bin/python3 ] && [ ! -e ${PREFIX}/bin/python ]; then
	ln -s python3 ${PREFIX}/bin/python
fi
PY_VER=$(${PREFIX}/bin/python -c "import sys; print('.'.join(str(v) for v in sys.version_info[:2]))")
PY_IMPL=$(${PREFIX}/bin/python -c "import sys; print(sys.implementation.name)")
PY_GIL=$(${PREFIX}/bin/python -c "import sysconfig; print('t' if sysconfig.get_config_vars().get('Py_GIL_DISABLED', 0) else '')")

# disable some pip warnings
export PIP_ROOT_USER_ACTION=ignore
export PIP_DISABLE_PIP_VERSION_CHECK=1
export PIP_NO_WARN_SCRIPT_LOCATION=0

# Install pinned packages for this python version.
if [ "${PY_IMPL}" == "graalpy" ]; then
	# GraalPy doesn't update pip/setuptools because it uses a patched version of pip/setuptools
	${PREFIX}/bin/python -m ensurepip --default-pip
	${PREFIX}/bin/python -m pip install -U --require-hashes -r ${MY_DIR}/requirements${PY_VER}.txt
elif [ -f /usr/local/bin/cpython${PY_VER} ]; then
	# Use the already intsalled cpython pip to bootstrap pip if available
	/usr/local/bin/cpython${PY_VER} -m pip --python ${PREFIX}/bin/python install -U --require-hashes -r ${MY_DIR}/requirements${PY_VER}.txt
else
	${PREFIX}/bin/python -m ensurepip
	${PREFIX}/bin/python -m pip install -U --require-hashes -r ${MY_DIR}/requirements${PY_VER}.txt
fi
if [ -e ${PREFIX}/bin/pip3 ] && [ ! -e ${PREFIX}/bin/pip ]; then
	ln -s pip3 ${PREFIX}/bin/pip
fi
# Create a symlink to PREFIX using the ABI_TAG in /opt/python/
ABI_TAG=$(${PREFIX}/bin/python ${MY_DIR}/python-tag-abi-tag.py)
ln -s ${PREFIX} /opt/python/${ABI_TAG}

# Make versioned python commands available directly in environment.
# Don't use symlinks: c.f. https://github.com/python/cpython/issues/106045
cat <<EOF > /usr/local/bin/${PY_IMPL}${PY_VER}${PY_GIL}
#!/bin/sh
exec /opt/python/${ABI_TAG}/bin/python "\$@"
EOF
chmod +x /usr/local/bin/${PY_IMPL}${PY_VER}${PY_GIL}
if [[ "${PY_IMPL}" == "cpython" ]]; then
	ln -s ${PY_IMPL}${PY_VER}${PY_GIL} /usr/local/bin/python${PY_VER}${PY_GIL}
fi

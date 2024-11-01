#!/bin/bash

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
source $MY_DIR/build_utils.sh

# most people don't need libpython*.a, and they're many megabytes.
# compress them all together for best efficiency
if [ $(find /opt/_internal -path '/opt/_internal/cpython-*/lib/libpython*.a' | wc -l) -ne 0 ]; then
	pushd /opt/_internal
	XZ_OPT=-9e tar -cJf static-libs-for-embedding-only.tar.xz cpython-*/lib/libpython*.a
	popd
fi
find /opt/_internal -name '*.a' -print0 | xargs -0 rm -f

# disable some pip warnings
export PIP_ROOT_USER_ACTION=ignore
export PIP_DISABLE_PIP_VERSION_CHECK=1
export PIP_NO_WARN_SCRIPT_LOCATION=0
# all cache goes to /tmp
export PIP_CACHE_DIR=/tmp/pip_cache

# update package, create symlinks for each python
mkdir /opt/python
for PREFIX in $(find /opt/_internal/ -mindepth 1 -maxdepth 1 -name 'cpython*'); do
	${MY_DIR}/finalize-one.sh ${PREFIX}
done

# create manylinux-interpreters script
cat <<EOF > /usr/local/bin/manylinux-interpreters
#!/bin/bash

set -euo pipefail

/opt/python/cp312-cp312/bin/python $MY_DIR/manylinux-interpreters.py "\$@"
EOF
chmod 755 /usr/local/bin/manylinux-interpreters

MANYLINUX_INTERPRETERS_NO_CHECK=1 /usr/local/bin/manylinux-interpreters ensure "$@"

# Create venv for certifi and pipx
TOOLS_PATH=/opt/_internal/tools
/opt/python/cp312-cp312/bin/python -m venv --without-pip ${TOOLS_PATH}

# Install certifi and pipx
/opt/python/cp312-cp312/bin/python -m pip --python ${TOOLS_PATH}/bin/python install -U --require-hashes -r ${MY_DIR}/requirements-base-tools.txt

# Make pipx available in PATH,
# Make sure when root installs apps, they're also in the PATH
cat <<EOF > /usr/local/bin/pipx
#!/bin/bash

set -euo pipefail

if [ \$(id -u) -eq 0 ]; then
	export PIPX_HOME=/opt/_internal/pipx
	export PIPX_BIN_DIR=/usr/local/bin
	export PIPX_MAN_DIR=/usr/local/share/man
fi
${TOOLS_PATH}/bin/pipx "\$@"
EOF
chmod 755 /usr/local/bin/pipx

# Our openssl doesn't know how to find the system CA trust store
#   (https://github.com/pypa/manylinux/issues/53)
# And it's not clear how up-to-date that is anyway
# So let's just use the same one pip and everyone uses
ln -s $(${TOOLS_PATH}/bin/python -c 'import certifi; print(certifi.where())') /opt/_internal/certs.pem
# If you modify this line you also have to modify the versions in the Dockerfiles:
export SSL_CERT_FILE=/opt/_internal/certs.pem

# initialize shared library
# workaround https://github.com/pypa/pip/issues/9243
/opt/python/cp312-cp312/bin/python -m pip download --dest /tmp/pinned-wheels --require-hashes -r /opt/_internal/build_scripts/requirements3.12.txt
pipx upgrade-shared --pip-args="--no-index --find-links=/tmp/pinned-wheels"

# install other tools with pipx
for TOOL_PATH in $(find ${MY_DIR}/requirements-tools -type f); do
	TOOL=$(basename ${TOOL_PATH})
	case ${AUDITWHEEL_PLAT}-${TOOL} in
		musllinux*_s390x-uv) continue;;  # uv doesn't provide musl s390x wheels due to Rust issues
		*) pipx install --pip-args="--require-hashes -r ${TOOL_PATH} --only-binary" ${TOOL};;
	esac
done

# We do not need the precompiled .pyc and .pyo files.
clean_pyc /opt/_internal

# remove cache
rm -rf /tmp/* || true

hardlink -c /opt/_internal

# update system packages
LC_ALL=C ${MY_DIR}/update-system-packages.sh

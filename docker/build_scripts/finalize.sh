#!/bin/bash

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
# shellcheck source-path=SCRIPTDIR
source "${MY_DIR}/build_utils.sh"

# most people don't need libpython*.a, and they're many megabytes.
# compress them all together for best efficiency
if [ "$(find /opt/_internal -path '/opt/_internal/cpython-*/lib/libpython*.a' | wc -l)" -ne 0 ]; then
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

# install tools first, we'll use them to patch python later on
TOOL_PYTHON3_MINOR=14
TOOLS_PATH=/opt/_internal/tools
TOOL_PYTHON_BASE=$(find /opt/_internal -maxdepth 1 -name "cpython-3.${TOOL_PYTHON3_MINOR}.*" -and -not -name '*-nogil')
TOOL_PYTHON=${TOOL_PYTHON_BASE}/bin/python3
${TOOL_PYTHON} -m ensurepip
${TOOL_PYTHON} -m pip install -U --require-hashes -r "${MY_DIR}/requirements-pip3.${TOOL_PYTHON3_MINOR}.txt"
${TOOL_PYTHON} -m pip install -U --require-hashes -r "${MY_DIR}/requirements3.${TOOL_PYTHON3_MINOR}.txt"
# Create venv for certifi and pipx
${TOOL_PYTHON} -m venv --without-pip ${TOOLS_PATH}
# Install certifi and pipx
${TOOL_PYTHON} -m pip --python ${TOOLS_PATH}/bin/python install -U --require-hashes -r "${MY_DIR}/requirements-base-tools.txt"

# Our openssl doesn't know how to find the system CA trust store
#   (https://github.com/pypa/manylinux/issues/53)
# And it's not clear how up-to-date that is anyway
# So let's just use the same one pip and everyone uses
ln -s "$(${TOOLS_PATH}/bin/python -c 'import certifi; print(certifi.where())')" /opt/_internal/certs.pem
export SSL_CERT_FILE=/opt/_internal/certs.pem

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

# use the same config for every tool, uv being one of the tools
export PIPX_DEFAULT_BACKEND=pip
export PIPX_FETCH_PYTHON=never

# initialize shared library
# workaround https://github.com/pypa/pip/issues/9243
${TOOL_PYTHON} -m pip download --dest /tmp/pinned-wheels --require-hashes -r /opt/_internal/build_scripts/requirements-pip3.${TOOL_PYTHON3_MINOR}.txt
pipx upgrade-shared --pip-args="--no-index --find-links=/tmp/pinned-wheels"

# install other tools with pipx
for TOOL_PATH in "${MY_DIR}/requirements-tools/"*; do
	TOOL=$(basename "${TOOL_PATH}")
	case ${AUDITWHEEL_PLAT}-${TOOL} in
		musllinux*_ppc64le-uv) continue;;  # uv doesn't provide musl ppc64le wheels due to Rust issues
		musllinux*_s390x-uv) continue;;  # uv doesn't provide musl s390x wheels due to Rust issues
		*_loongarch64-uv) continue;;  # no uv for loongarch64
		*_loongarch64-cmake|*_loongarch64-swig) manylinux_pkg_install "${TOOL}";;
		*_loongarch64-patchelf)
			manylinux_pkg_install cmake
			pipx install patchelf==0.17.2.4
			;;
		*) pipx install --pip-args="--require-hashes -r ${TOOL_PATH} --only-binary" "${TOOL}";;
	esac
done

# download and patch pip for each python version
for REQUIREMENTS in /opt/_internal/build_scripts/requirements-pip3.*; do
	REQUIREMENTS_BASENAME=$(basename "${REQUIREMENTS}" .txt)
	PY_VER=${REQUIREMENTS_BASENAME:16}
	${TOOL_PYTHON} -m pip download --dest "/tmp/pip-wheels/" --require-hashes -c "${REQUIREMENTS}" pip
done

mkdir /tmp/patched-pip-wheels
mkdir /tmp/patch-pip
pushd /tmp/patch-pip
for PIP_WHEEL in /tmp/pip-wheels/pip-*.whl; do
	wheel unpack "${PIP_WHEEL}"
	PIP_CACERT_PEM=$(find . -path '*/_vendor/certifi/cacert.pem')
	cp -f ${SSL_CERT_FILE} "${PIP_CACERT_PEM}"
	wheel pack -d /tmp/patched-pip-wheels --local-version manylinux ./pip-*
	rm -rf ./pip-*
done
popd

mkdir /opt/_internal/pip-wheels
for REQUIREMENTS in /opt/_internal/build_scripts/requirements-pip3.*; do
	REQUIREMENTS_BASENAME=$(basename "${REQUIREMENTS}" .txt)
	PY_VER=${REQUIREMENTS_BASENAME:16}
	PIP_VERSION=$(grep 'pip==' "${REQUIREMENTS}")
	PIP_VERSION=${PIP_VERSION:5}
	PIP_VERSION=${PIP_VERSION%% *}
	SRC_WHEEL=$(find /tmp/patched-pip-wheels -name "pip-${PIP_VERSION}+manylinux-*.whl")
	mkdir "/opt/_internal/pip-wheels/${PY_VER}"
	cp "${SRC_WHEEL}" "/opt/_internal/pip-wheels/${PY_VER}/"
done

# update package, create symlinks for each python
mkdir /opt/python
for PREFIX in /opt/_internal/cpython*; do
	"${MY_DIR}/finalize-one.sh" "${PREFIX}"
done

# create manylinux-interpreters script
cat <<EOF > /usr/local/bin/manylinux-interpreters
#!/bin/bash

set -euo pipefail

${TOOL_PYTHON} "${MY_DIR}/manylinux-interpreters.py" "\$@"
EOF
chmod 755 /usr/local/bin/manylinux-interpreters

MANYLINUX_INTERPRETERS_NO_CHECK=1 /usr/local/bin/manylinux-interpreters ensure "$@"

# install git-lfs
"${MY_DIR}/install-git-lfs.sh"

# We do not need the precompiled .pyc and .pyo files.
clean_pyc /opt/_internal

# remove cache
rm -rf /tmp/* || true

hardlink -c /opt/_internal

# update system packages
LC_ALL=C "${MY_DIR}/update-system-packages.sh"

# wrap compilers (see https://github.com/pypa/manylinux/issues/1725)
"${MY_DIR}/install-gcc-wrapper.sh"

# patch libstdc++.so  (see https://github.com/pypa/manylinux/issues/1760)
if [ "${AUDITWHEEL_POLICY}" == "manylinux_2_28" ] || [ "${AUDITWHEEL_POLICY}" == "manylinux_2_34" ]; then
	find "${DEVTOOLSET_ROOTPATH}" -name 'libstdc++.so' -exec sed -i 's/INPUT\s*(\s*\([^ ]\+\)\s*\([^ ]\+\)\s*)/INPUT ( \1 \2 \1 )/g' {} \;
fi

# add clang install helper
ln -s "${MY_DIR}/install-static-clang-helper.sh" /usr/local/bin/manylinux-install-clang

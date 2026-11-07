#!/bin/bash

# Stop at any error, show all commands
set -exuo pipefail

# Get script directory
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# https://github.com/pypa/manylinux/pull/2004
# check curl does not trust some compromised CA
URLS_TO_CHECK=(
	"https://dv-g3b-emudhra.we-have-a-problem.com/"
	"https://dv-g3b-aaa-emudhra.we-have-a-problem.com/"
	"https://dv-g3b-noct-emudhra.we-have-a-problem.com/"
	"https://dv-g3b-aaa-noct-emudhra.we-have-a-problem.com/"
)
SSL_CERT_FILE_BACKUP=${SSL_CERT_FILE}
unset SSL_CERT_FILE
for _UNUSED in "SSL_CERT_FILE_UNSET" "SSL_CERT_FILE_SET"; do
	for URL_TO_CHECK in "${URLS_TO_CHECK[@]}"; do
		CURL_EC=0
		curl -fs "${URL_TO_CHECK}" || CURL_EC=$?
		# 60: Peer certificate cannot be authenticated with known CA certificates.
		if [ ${CURL_EC} -ne 60 ]; then
			exit 1
		fi
	done
	export SSL_CERT_FILE=${SSL_CERT_FILE_BACKUP}
done

if [ "${AUDITWHEEL_POLICY:0:10}" == "musllinux_" ]; then
	EXPECTED_PYTHON_COUNT=9
	EXPECTED_PYTHON_COUNT_ALL=9
else
	if [ "${AUDITWHEEL_ARCH}" == "x86_64" ] || [ "${AUDITWHEEL_ARCH}" == "aarch64" ]; then
		if [ "${AUDITWHEEL_POLICY:0:13}" == "manylinux2014" ]; then
			EXPECTED_PYTHON_COUNT=10
			EXPECTED_PYTHON_COUNT_ALL=14
		else
			EXPECTED_PYTHON_COUNT=12
			EXPECTED_PYTHON_COUNT_ALL=17
		fi
	elif [ "${AUDITWHEEL_ARCH}" == "i686" ]; then
		if [ "${AUDITWHEEL_POLICY:0:13}" == "manylinux2014" ]; then
		  EXPECTED_PYTHON_COUNT=10
		  EXPECTED_PYTHON_COUNT_ALL=12
		else
			EXPECTED_PYTHON_COUNT=12
			EXPECTED_PYTHON_COUNT_ALL=14
		fi
	else
		EXPECTED_PYTHON_COUNT=9
		EXPECTED_PYTHON_COUNT_ALL=9
	fi
fi

# the following environment variable allows other manylinux-like projects to run
# the same tests as manylinux without the same number of CPython installations
if [ "${ADJUST_CPYTHON_COUNT:-}" != "" ]; then
	EXPECTED_PYTHON_COUNT=$(( EXPECTED_PYTHON_COUNT + ADJUST_CPYTHON_COUNT ))
	EXPECTED_PYTHON_COUNT_ALL=$(( EXPECTED_PYTHON_COUNT_ALL + ADJUST_CPYTHON_COUNT ))
fi

PYTHON_COUNT=$(manylinux-interpreters list --installed | wc -l)
if [ "${EXPECTED_PYTHON_COUNT}" -ne "${PYTHON_COUNT}" ]; then
	echo "unexpected number of default python installations: ${PYTHON_COUNT}, expecting ${EXPECTED_PYTHON_COUNT}"
	manylinux-interpreters list --installed
	exit 1
fi
PYTHON_COUNT_ALL=$(manylinux-interpreters list | wc -l)
if [ "${EXPECTED_PYTHON_COUNT_ALL}" -ne "${PYTHON_COUNT_ALL}" ]; then
	echo "unexpected number of overall python installations: ${PYTHON_COUNT_ALL}, expecting ${EXPECTED_PYTHON_COUNT_ALL}"
	manylinux-interpreters list
	exit 1
fi
manylinux-interpreters ensure-all
PYTHON_COUNT=$(manylinux-interpreters list --installed | wc -l)
if [ "${EXPECTED_PYTHON_COUNT_ALL}" -ne "${PYTHON_COUNT}" ]; then
	echo "unexpected number of python installations after 'manylinux-python ensure-all': ${PYTHON_COUNT}, expecting ${EXPECTED_PYTHON_COUNT_ALL}"
	manylinux-interpreters list --installed
	exit 1
fi

# build dependencies for extension build smoke test
make -C "${MY_DIR}/forty-two" all

PYTHONS="$(find /opt/python -mindepth 1 -maxdepth 1)"
PYTHON_COUNT=$(echo "${PYTHONS}" | wc -l)
if [ "${EXPECTED_PYTHON_COUNT_ALL}" -ne "${PYTHON_COUNT}" ]; then
	echo "all python installations were not tested: ${PYTHON_COUNT}, expecting ${EXPECTED_PYTHON_COUNT_ALL}"
	ls /opt/python
	exit 1
fi
echo "${PYTHONS}" | xargs -L 1 -P 0 "${MY_DIR}/run_tests_interpreter.sh"

# minimal tests for tools that should be present
abi3audit --version
auditwheel --version
autoconf --version
automake --version
libtoolize --version
patchelf --version
git --version
git lfs --version
cmake --version
swig -version
pipx run nox --version
pipx install nox
nox --version
tar --version | grep "GNU tar"

# check libcrypt.so.1 can be loaded by some system packages,
# as LD_LIBRARY_PATH might not be enough.
# c.f. https://github.com/pypa/manylinux/issues/1022
if [ "${AUDITWHEEL_POLICY}" == "manylinux2014" ]; then
	yum -y install openssh-clients
	eval "$(ssh-agent)"
	eval "$(ssh-agent -k)"
fi

if [ "${AUDITWHEEL_POLICY}" == "manylinux2014" ] || [ "${AUDITWHEEL_POLICY}" == "manylinux_2_28" ] || [ "${AUDITWHEEL_POLICY}" == "musllinux_1_2" ]; then
	# we stopped installing sqlite3 after manylinux_2_28 / musllinux_1_2 & this is becoming an internal detail
	/opt/_internal/sqlite3/bin/sqlite3 --version
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

if [ "${AUDITWHEEL_ARCH}" == "x86_64" ]; then
	# yasm available
	yasm --version

	# https://github.com/pypa/manylinux/issues/1725
	# check the compiler does not default to x86-64-v?
	which gcc
	gcc --version
	if echo | gcc -S -x c -v - 2>&1 | grep 'march=x86-64-v'; then
		echo "wrong target architecture"
		exit 1
	fi
fi

# https://github.com/pypa/manylinux/issues/1760
g++ -o /tmp/repro -x c++ -D_GLIBCXX_ASSERTIONS -fPIC -Wl,--as-needed - << EOF
#include <array>
#include <cstdio>

int main(int argc, char* argv[])
{
  std::array<int, 3> a = {1, 2, 3};
  printf("repro %d\n", a[0]);
  return 0;
}
EOF
/tmp/repro

# check autotools
pushd "$(mktemp -d)"
cp -rf "${MY_DIR}/autotools"/* ./
autoreconf -ifv
./configure
popd

# check clang
if manylinux-install-clang -v 18.0; then
		echo "installing clang 18.0 should fail"
		exit 1
fi
if ! manylinux-install-clang -l | grep 'v21.1.8.1'; then
		echo "clang v21.1.8.1 should be listed as an available version"
		exit 1
fi
if manylinux-install-clang -v 21.1.8.1 -c bad_sha; then
		echo "installing clang with a bad sha256 should fail"
		exit 1
fi
if manylinux-install-clang -v 21.1.8.1 -m bad_arch; then
		echo "installing clang with a bad architecture should fail"
		exit 1
fi

manylinux-install-clang -v v21.1.8.1 -c a6f87a4af8d72192219602f252d7debdf7c1e73ca4b28a2f99f2832a3ac0b487
clang --version | grep '21.1.8'
rm -rf /opt/clang

# default/stable should be 21
manylinux-install-clang
clang --version | grep '21.'
rm -rf /opt/clang
manylinux-install-clang -v stable
clang --version | grep '21.'
rm -rf /opt/clang
# latest should be 23
manylinux-install-clang -v latest
clang --version | grep '23.'
rm -rf /opt/clang

manylinux-install-clang -m "$(uname -m)"
clang --version
rm -rf /opt/clang

manylinux-install-clang
clang --version
for TOOL in clang clang++ lld ar nm objcopy ranlib readelf; do
	if [ "$(which ${TOOL})" != "/opt/clang/bin/${TOOL}" ]; then
			echo "${TOOL} was not resolved from /opt/clang/bin"
			exit 1
	fi
done
rm -rf /opt/clang

# final report
echo "run_tests successful!"

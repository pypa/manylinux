#!/bin/bash

# Stop at any error, show all commands
set -exuo pipefail

# Set build environment variables
MY_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
STATIC_CLANG_VERSIONS="${MY_DIR}/static_clang_versions.txt"

usage() {
	echo "usage: $0 [-v <version>] [-c <sha256-of-sha256sums.txt>] [-m <machine>] [-l] [-h]"
	echo ""
	echo "options:"
	echo "  -v <version>                    Static clang version to install"
	echo "  -c <sha256-of-sha256sums.txt>   SHA-256 of sha256sums.txt (not the toolchain archive)"
	echo "  -m <machine>                    Target machine/architecture"
	echo "  -l                              List available versions"
	echo "  -h                              Show this help"
}

CLANG_ARCH=
CLANG_VERSION=
CLANG_SHA256SUMS_FILE_SHA256=

while getopts ":v:c:m:lh" OPTION; do
	case "${OPTION}" in
		v) CLANG_VERSION=${OPTARG};;
		c) CLANG_SHA256SUMS_FILE_SHA256=${OPTARG};;
		m) CLANG_ARCH=${OPTARG};;
		l) awk '{ print $1 }' "${STATIC_CLANG_VERSIONS}"; exit 0;;
		h) usage; exit 0;;
		*) usage 1>&2; exit 1;;
	esac
done

TOOLCHAIN_PATH=/opt/clang

# get & check architecture
if [ "${CLANG_ARCH}" == "" ]; then
	DEFAULT_ARCH="$(uname -m)"
	CLANG_ARCH="${RUNNER_ARCH:-${DEFAULT_ARCH}}"
fi
case "${CLANG_ARCH}" in
	ARM64|aarch64|arm64|arm64/*) GO_ARCH=arm64;;
	ARM|armv7l|armv8l|arm|arm/v7) GO_ARCH=arm;;  # assume arm/v7 for arm
	X64|x86_64|amd64|amd64/*) GO_ARCH=amd64;;
	X86|i686|386) GO_ARCH=386;;
	ppc64le) GO_ARCH=ppc64le;;
	riscv64) GO_ARCH=riscv64;;
	s390x) GO_ARCH=s390x;;
	*) echo "No static-clang toolchain for ${CLANG_ARCH}" 1>&2; exit 1;;
esac

# get version & sha256
if [ "${CLANG_VERSION}" == "" ]; then
	CLANG_VERSION=stable
fi

if [ "${CLANG_VERSION}" == "stable" ]; then
	# || test $? -eq 141 is there to ignore SIGPIPE with set -o pipefail
  # c.f. https://stackoverflow.com/questions/22464786/ignoring-bash-pipefail-for-error-code-141#comment60412687_33026977
	CLANG_VERSION=$( (grep "v21." "${STATIC_CLANG_VERSIONS}" | head -1 || test $? -eq 141) | awk '{ print $1 }')
elif [ "${CLANG_VERSION}" == "latest" ]; then
	CLANG_VERSION=$(head -1 "${STATIC_CLANG_VERSIONS}" | awk '{ print $1 }')
fi

if [ "${CLANG_VERSION:0:1}" != "v" ]; then
	CLANG_VERSION="v${CLANG_VERSION}"
fi

CLANG_SHA256SUMS_FILE_SHA256_DEFAULT=${CLANG_SHA256SUMS_FILE_SHA256}
if awk -v version="${CLANG_VERSION}" '$1 == version { found = 1; exit } END { exit !found }' "${STATIC_CLANG_VERSIONS}"; then
	CLANG_SHA256SUMS_FILE_SHA256_DEFAULT=$(awk -v version="${CLANG_VERSION}" '$1 == version { print $2; exit }' "${STATIC_CLANG_VERSIONS}")
fi

if [ "${CLANG_SHA256SUMS_FILE_SHA256}" == "" ]; then
	if [ "${CLANG_SHA256SUMS_FILE_SHA256_DEFAULT}" == "" ]; then
		echo "No known sha256 for static-clang toolchain ${CLANG_VERSION}" 1>&2
		exit 1
	fi
	CLANG_SHA256SUMS_FILE_SHA256=${CLANG_SHA256SUMS_FILE_SHA256_DEFAULT}
elif [ "${CLANG_SHA256SUMS_FILE_SHA256}" != "${CLANG_SHA256SUMS_FILE_SHA256_DEFAULT}" ]; then
	echo "Bad sha256 for static-clang toolchain ${CLANG_VERSION}, user passed '${CLANG_SHA256SUMS_FILE_SHA256}', expected '${CLANG_SHA256SUMS_FILE_SHA256_DEFAULT}'" 1>&2
	exit 1
fi

# Download static-clang
CLANG_SHA256_FILENAME=sha256sums.txt
CLANG_SHA256_URL="https://github.com/mayeut/static-clang-images/releases/download/${CLANG_VERSION}/${CLANG_SHA256_FILENAME}"
CLANG_FILENAME="static-clang-linux-${GO_ARCH}.tar.xz"
CLANG_URL="https://github.com/mayeut/static-clang-images/releases/download/${CLANG_VERSION}/${CLANG_FILENAME}"
pushd /tmp &> /dev/null
curl -fsSLO "${CLANG_SHA256_URL}"
echo "${CLANG_SHA256SUMS_FILE_SHA256}  ${CLANG_SHA256_FILENAME}" | sha256sum -c -
CLANG_SHA256=$(awk -v filename="${CLANG_FILENAME}" '$2 == filename { print $1; exit }' "${CLANG_SHA256_FILENAME}")
curl -fsSLO "${CLANG_URL}"
echo "${CLANG_SHA256}  ${CLANG_FILENAME}" | sha256sum -c -
rm -rf /opt/clang || true
tar -C /opt -xJf "${CLANG_FILENAME}"
rm -f "${CLANG_FILENAME}" "${CLANG_SHA256_FILENAME}" || true
popd  &> /dev/null

# configure target triple
case "${AUDITWHEEL_POLICY}-${AUDITWHEEL_ARCH}" in
	manylinux*-armv7l) TARGET_TRIPLE=armv7-unknown-linux-gnueabihf;;
	musllinux*-armv7l) TARGET_TRIPLE=armv7-alpine-linux-musleabihf;;
	manylinux*-ppc64le) TARGET_TRIPLE=powerpc64le-unknown-linux-gnu;;
	musllinux*-ppc64le) TARGET_TRIPLE=powerpc64le-alpine-linux-musl;;
	manylinux*-*) TARGET_TRIPLE=${AUDITWHEEL_ARCH}-unknown-linux-gnu;;
	musllinux*-*) TARGET_TRIPLE=${AUDITWHEEL_ARCH}-alpine-linux-musl;;
esac
case "${AUDITWHEEL_POLICY}-${AUDITWHEEL_ARCH}" in
	*-riscv64) M_ARCH="-march=rv64gc";;
	*-x86_64) M_ARCH="-march=x86-64";;
	*-armv7l) M_ARCH="-march=armv7a";;
	manylinux*-i686) M_ARCH="-march=k8 -mtune=generic";;  # same as gcc manylinux2014 / manylinux_2_28
	musllinux*-i686) M_ARCH="-march=pentium-m -mtune=generic";;  # same as gcc musllinux_1_2
esac
GCC_TRIPLE=$(gcc -dumpmachine)

cat<<EOF >"${TOOLCHAIN_PATH}/bin/${AUDITWHEEL_PLAT}.cfg"
	-target ${TARGET_TRIPLE}
	${M_ARCH:-}
	--gcc-toolchain=${DEVTOOLSET_ROOTPATH:-}/usr
	--gcc-triple=${GCC_TRIPLE}
EOF

cat<<EOF >"${TOOLCHAIN_PATH}/bin/clang.cfg"
	@${AUDITWHEEL_PLAT}.cfg
EOF

cat<<EOF >"${TOOLCHAIN_PATH}/bin/clang++.cfg"
	@${AUDITWHEEL_PLAT}.cfg
EOF

cat<<EOF >"${TOOLCHAIN_PATH}/bin/clang-cpp.cfg"
	@${AUDITWHEEL_PLAT}.cfg
EOF

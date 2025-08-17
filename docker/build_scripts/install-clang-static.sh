#!/bin/bash
# Install packages that will be needed at runtime

# Stop at any error, show all commands
set -exuo pipefail

# Set build environment variables
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
# shellcheck source-path=SCRIPTDIR
source "${MY_DIR}/build_utils.sh"

case "${BASE_POLICY}-${AUDITWHEEL_ARCH}" in
	manylinux-armv7l) TARGET_TRIPLE=armv7-unknown-linux-gnueabihf;;
	musllinux-armv7l) TARGET_TRIPLE=armv7-alpine-linux-musleabihf;;
	manylinux-ppc64le) TARGET_TRIPLE=powerpc64le-unknown-linux-gnu;;
	musllinux-ppc64le) TARGET_TRIPLE=powerpc64le-alpine-linux-musl;;
	manylinux-*) TARGET_TRIPLE=${AUDITWHEEL_ARCH}-unknown-linux-gnu;;
	musllinux-*) TARGET_TRIPLE=${AUDITWHEEL_ARCH}-alpine-linux-musl;;
esac
case "${AUDITWHEEL_ARCH}" in
	riscv64) M_ARCH="-march=rv64gc";;
	x86_64) M_ARCH="-march=x86-64";;
	armv7l) M_ARCH="-march=armv7a";;
	i686) M_ARCH="-march=i686";;
esac
GCC_TRIPLE=$(gcc -dumpmachine)

TOOLCHAIN_PATH="$1"
ln -s clang "${TOOLCHAIN_PATH}/bin/gcc"
ln -s clang "${TOOLCHAIN_PATH}/bin/cc"
ln -s clang-cpp "${TOOLCHAIN_PATH}/bin/cpp"
ln -s clang++ "${TOOLCHAIN_PATH}/bin/g++"
ln -s clang++ "${TOOLCHAIN_PATH}/bin/c++"

cat<<EOF >"${TOOLCHAIN_PATH}/bin/${AUDITWHEEL_PLAT}.cfg"
	-target ${TARGET_TRIPLE}
	${M_ARCH:-}
	--gcc-toolchain=${DEVTOOLSET_ROOTPATH:-}/usr
	--gcc-triple=${GCC_TRIPLE}
EOF

cat<<EOF >"${TOOLCHAIN_PATH}/bin/clang.cfg"
	@${AUDITWHEEL_PLAT}.cfg
	-fuse-ld=lld
EOF
cat<<EOF >"${TOOLCHAIN_PATH}/bin/clang++.cfg"
	@${AUDITWHEEL_PLAT}.cfg
	-fuse-ld=lld
EOF
cat<<EOF >"${TOOLCHAIN_PATH}/bin/clang-cpp.cfg"
	@${AUDITWHEEL_PLAT}.cfg
EOF

cat<<EOF >"${TOOLCHAIN_PATH}/entrypoint"
#!/bin/bash

set -eu
export MANYLINUX_DISABLE_CLANG=${MANYLINUX_DISABLE_CLANG}
if [ ${MANYLINUX_DISABLE_CLANG} -eq 0 ] && [ \${MANYLINUX_DISABLE_CLANG_FOR_CPYTHON:-0} -eq 0 ]; then
	export PATH="${TOOLCHAIN_PATH}/bin:\${PATH}"
fi
exec manylinux-entrypoint "\$@"
EOF

chmod +x "${TOOLCHAIN_PATH}/entrypoint"

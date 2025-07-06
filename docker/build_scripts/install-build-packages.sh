#!/bin/bash
# Install packages that will be needed at runtime

# Stop at any error, show all commands
set -exuo pipefail

# Set build environment variables
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
# shellcheck source-path=SCRIPTDIR
source "${MY_DIR}/build_utils.sh"

# if a devel package is added to COMPILE_DEPS,
# make sure the corresponding library is added to RUNTIME_DEPS if applicable

if [ "${OS_ID_LIKE}" = "rhel" ]; then
	COMPILE_DEPS=(bzip2-devel ncurses-devel readline-devel gdbm-devel xz-devel openssl openssl-devel curl-devel uuid-devel libffi-devel kernel-headers perl-IPC-Cmd)
	if [ "${AUDITWHEEL_POLICY}" == "manylinux2014" ]; then
		COMPILE_DEPS+=(libXft-devel)
		COMPILE_DEPS+=(keyutils-libs-devel krb5-devel libcom_err-devel libidn-devel)  # we rebuild curl
	elif [ "${AUDITWHEEL_POLICY}" == "manylinux_2_28" ]; then
		COMPILE_DEPS+=(tk-devel)
	else
		COMPILE_DEPS+=(tk-devel)
	fi
elif [ "${OS_ID_LIKE}" == "debian" ]; then
	COMPILE_DEPS=(libbz2-dev libncurses-dev libreadline-dev tk-dev libgdbm-dev libdb-dev liblzma-dev openssl libssl-dev libcurl4-openssl-dev uuid-dev libffi-dev linux-headers-generic)
elif [ "${OS_ID_LIKE}" == "alpine" ]; then
	COMPILE_DEPS=(bzip2-dev ncurses-dev readline-dev tk-dev gdbm-dev xz-dev openssl openssl-dev curl-dev util-linux-dev libffi-dev linux-headers)
else
	echo "Unsupported policy: '${AUDITWHEEL_POLICY}'"
	exit 1
fi

manylinux_pkg_install "${COMPILE_DEPS[@]}"
manylinux_pkg_clean

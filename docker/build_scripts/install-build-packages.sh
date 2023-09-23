#!/bin/bash
# Install packages that will be needed at runtime

# Stop at any error, show all commands
set -exuo pipefail

# Set build environment variables
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
source $MY_DIR/build_utils.sh

# if a devel package is added to COMPILE_DEPS,
# make sure the corresponding library is added to RUNTIME_DEPS if applicable

if [ "${BASE_POLICY}" == "manylinux" ]; then
	COMPILE_DEPS="bzip2-devel ncurses-devel readline-devel gdbm-devel libpcap-devel xz-devel openssl openssl-devel keyutils-libs-devel krb5-devel libcom_err-devel libidn-devel curl-devel uuid-devel libffi-devel kernel-headers libdb-devel perl-IPC-Cmd"
	if [ "${AUDITWHEEL_POLICY}" == "manylinux2014" ]; then
		PACKAGE_MANAGER=yum
		COMPILE_DEPS="${COMPILE_DEPS} libXft-devel"
	else
		PACKAGE_MANAGER=dnf
		COMPILE_DEPS="${COMPILE_DEPS} tk-devel"
	fi
elif [ "${BASE_POLICY}" == "musllinux" ]; then
	PACKAGE_MANAGER=apk
	COMPILE_DEPS="bzip2-dev ncurses-dev readline-dev tk-dev gdbm-dev libpcap-dev xz-dev openssl openssl-dev keyutils-dev krb5-dev libcom_err libidn-dev curl-dev util-linux-dev libffi-dev linux-headers"
else
	echo "Unsupported policy: '${AUDITWHEEL_POLICY}'"
	exit 1
fi


if [ "${PACKAGE_MANAGER}" == "yum" ]; then
	yum -y install ${COMPILE_DEPS}
	yum clean all
	rm -rf /var/cache/yum
elif [ "${PACKAGE_MANAGER}" == "apk" ]; then
	apk add --no-cache ${COMPILE_DEPS}
elif [ "${PACKAGE_MANAGER}" == "dnf" ]; then
 	dnf -y install --allowerasing ${COMPILE_DEPS}
 	dnf clean all
 	rm -rf /var/cache/yum
else
	echo "Not implemented"
	exit 1
fi

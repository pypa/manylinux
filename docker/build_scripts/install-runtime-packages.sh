#!/bin/bash
# Install packages that will be needed at runtime

# Stop at any error, show all commands
set -exuo pipefail

# Set build environment variables
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
source $MY_DIR/build_utils.sh

# Libraries that are allowed as part of the manylinux2014 profile
# Extract from PEP: https://www.python.org/dev/peps/pep-0599/#the-manylinux2014-policy
# On RPM-based systems, they are provided by these packages:
# Package:    Libraries
# glib2:      libglib-2.0.so.0, libgthread-2.0.so.0, libgobject-2.0.so.0
# glibc:      libresolv.so.2, libutil.so.1, libnsl.so.1, librt.so.1, libpthread.so.0, libdl.so.2, libm.so.6, libc.so.6
# libICE:     libICE.so.6
# libX11:     libX11.so.6
# libXext:    libXext.so.6
# libXrender: libXrender.so.1
# libgcc:     libgcc_s.so.1
# libstdc++:  libstdc++.so.6
# mesa:       libGL.so.1
#
# PEP is missing the package for libSM.so.6 for RPM based system
#
# With PEP600, more packages are allowed by auditwheel policies
# - libz.so.1
# - libexpat.so.1


# MANYLINUX_DEPS: Install development packages (except for libgcc which is provided by gcc install)
if [ "${AUDITWHEEL_POLICY}" == "manylinux2014" ] || [ "${AUDITWHEEL_POLICY}" == "manylinux_2_28" ]; then
	MANYLINUX_DEPS="glibc-devel libstdc++-devel glib2-devel libX11-devel libXext-devel libXrender-devel mesa-libGL-devel libICE-devel libSM-devel zlib-devel expat-devel"
elif [ "${BASE_POLICY}" == "musllinux" ]; then
	MANYLINUX_DEPS="musl-dev libstdc++ glib-dev libx11-dev libxext-dev libxrender-dev mesa-dev libice-dev libsm-dev zlib-dev expat-dev"
else
	echo "Unsupported policy: '${AUDITWHEEL_POLICY}'"
	exit 1
fi

# RUNTIME_DEPS: Runtime dependencies. c.f. install-build-packages.sh
if [ "${AUDITWHEEL_POLICY}" == "manylinux2014" ] || [ "${AUDITWHEEL_POLICY}" == "manylinux_2_28" ]; then
	RUNTIME_DEPS="zlib bzip2 expat ncurses readline gdbm libpcap xz openssl keyutils-libs libkadm5 libcom_err libidn libcurl uuid libffi libdb"
    if [ "${AUDITWHEEL_POLICY}" == "manylinux_2_28" ]; then
        RUNTIME_DEPS="${RUNTIME_DEPS} tk"
    fi
elif [ "${BASE_POLICY}" == "musllinux" ]; then
	RUNTIME_DEPS="zlib bzip2 expat ncurses-libs readline tk gdbm db xz openssl keyutils-libs krb5-libs libcom_err libidn2 libcurl libuuid libffi"
else
	echo "Unsupported policy: '${AUDITWHEEL_POLICY}'"
	exit 1
fi

BASETOOLS="autoconf automake bison bzip2 diffutils file make patch unzip"
if [ "${AUDITWHEEL_POLICY}" == "manylinux2014" ]; then
	PACKAGE_MANAGER=yum
	BASETOOLS="${BASETOOLS} hardlink hostname which"
	# See https://unix.stackexchange.com/questions/41784/can-yum-express-a-preference-for-x86-64-over-i386-packages
	echo "multilib_policy=best" >> /etc/yum.conf
	# Error out if requested packages do not exist
	echo "skip_missing_names_on_install=False" >> /etc/yum.conf
	# Make sure that locale will not be removed
	sed -i '/^override_install_langs=/d' /etc/yum.conf
	# Exclude mirror holding broken package metadata
	echo "exclude = d36uatko69830t.cloudfront.net" >> /etc/yum/pluginconf.d/fastestmirror.conf
	yum -y update
	yum -y install yum-utils curl
	yum-config-manager --enable extras
	TOOLCHAIN_DEPS="devtoolset-10-binutils devtoolset-10-gcc devtoolset-10-gcc-c++ devtoolset-10-gcc-gfortran"
	if [ "${AUDITWHEEL_ARCH}" == "x86_64" ]; then
		# Software collection (for devtoolset-10)
		yum -y install centos-release-scl-rh
		# EPEL support (for yasm)
		yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
		TOOLCHAIN_DEPS="${TOOLCHAIN_DEPS} yasm"
	elif [ "${AUDITWHEEL_ARCH}" == "aarch64" ] || [ "${AUDITWHEEL_ARCH}" == "ppc64le" ] || [ "${AUDITWHEEL_ARCH}" == "s390x" ]; then
		# Software collection (for devtoolset-10)
		yum -y install centos-release-scl-rh
	elif [ "${AUDITWHEEL_ARCH}" == "i686" ]; then
		# No yasm on i686
		# Install mayeut/devtoolset-10 repo to get devtoolset-10
		curl -fsSLo /etc/yum.repos.d/mayeut-devtoolset-10.repo https://copr.fedorainfracloud.org/coprs/mayeut/devtoolset-10/repo/custom-1/mayeut-devtoolset-10-custom-1.repo
	fi
elif [ "${AUDITWHEEL_POLICY}" == "manylinux_2_28" ]; then
	PACKAGE_MANAGER=dnf
	BASETOOLS="${BASETOOLS} curl glibc-locale-source glibc-langpack-en hardlink hostname libcurl libnsl libxcrypt which"
	# See https://unix.stackexchange.com/questions/41784/can-yum-express-a-preference-for-x86-64-over-i386-packages
	echo "multilib_policy=best" >> /etc/yum.conf
	# Error out if requested packages do not exist
	echo "skip_missing_names_on_install=False" >> /etc/yum.conf
	# Make sure that locale will not be removed
	sed -i '/^override_install_langs=/d' /etc/yum.conf
	dnf -y upgrade
	dnf -y install dnf-plugins-core
	dnf config-manager --set-enabled powertools # for yasm
	TOOLCHAIN_DEPS="gcc-toolset-12-binutils gcc-toolset-12-gcc gcc-toolset-12-gcc-c++ gcc-toolset-12-gcc-gfortran"
	if [ "${AUDITWHEEL_ARCH}" == "x86_64" ]; then
		TOOLCHAIN_DEPS="${TOOLCHAIN_DEPS} yasm"
	fi
elif [ "${BASE_POLICY}" == "musllinux" ]; then
	TOOLCHAIN_DEPS="binutils gcc g++ gfortran"
	BASETOOLS="${BASETOOLS} curl util-linux tar"
	PACKAGE_MANAGER=apk
	apk add --no-cache ca-certificates gnupg
else
	echo "Unsupported policy: '${AUDITWHEEL_POLICY}'"
	exit 1
fi

if [ "${PACKAGE_MANAGER}" == "yum" ]; then
	yum -y install ${BASETOOLS} ${TOOLCHAIN_DEPS} ${MANYLINUX_DEPS} ${RUNTIME_DEPS}
elif [ "${PACKAGE_MANAGER}" == "apk" ]; then
	apk add --no-cache ${BASETOOLS} ${TOOLCHAIN_DEPS} ${MANYLINUX_DEPS} ${RUNTIME_DEPS}
elif [ "${PACKAGE_MANAGER}" == "dnf" ]; then
	dnf -y install --allowerasing ${BASETOOLS} ${TOOLCHAIN_DEPS} ${MANYLINUX_DEPS} ${RUNTIME_DEPS}
else
	echo "Not implemented"
	exit 1
fi

# update system packages, we already updated them but
# the following script takes care of cleaning-up some things
# and since it's also needed in the finalize step, everything's
# centralized in this script to avoid code duplication
LC_ALL=C ${MY_DIR}/update-system-packages.sh

if [ "${BASE_POLICY}" == "manylinux" ]; then
	# we'll be removing libcrypt.so.1 later on
	# this is needed to ensure the new one will be found
	# as LD_LIBRARY_PATH does not seem enough.
	# c.f. https://github.com/pypa/manylinux/issues/1022
	echo "/usr/local/lib" > /etc/ld.so.conf.d/00-manylinux.conf
	ldconfig
fi

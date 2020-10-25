#!/bin/bash
# Install packages that will be needed at runtime

# Stop at any error, show all commands
set -exuo pipefail


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
# Install development packages (except for libgcc which is provided by gcc install)
if [ "${AUDITWHEEL_POLICY}" == "manylinux2014" ]; then
	MANYLINUX_DEPS="glibc-devel libstdc++-devel glib2-devel libX11-devel libXext-devel libXrender-devel mesa-libGL-devel libICE-devel libSM-devel"
elif [ "${AUDITWHEEL_POLICY}" == "manylinux_2_24" ]; then
	MANYLINUX_DEPS="libc6-dev libstdc++-6-dev libglib2.0-dev libx11-dev libxext-dev libxrender-dev libgl1-mesa-dev libice-dev libsm-dev"
else
	echo "Unsupported policy: '${AUDITWHEEL_POLICY}'"
	exit 1
fi


# Runtime dependencies. c.f. install-build-packages.sh
if [ "${AUDITWHEEL_POLICY}" == "manylinux2014" ]; then
	RUNTIME_DEPS="zlib bzip2 expat ncurses readline tk gdbm libdb libpcap xz openssl keyutils-libs libkadm5 libcom_err libidn libcurl uuid libffi"
elif [ "${AUDITWHEEL_POLICY}" == "manylinux_2_24" ]; then
	RUNTIME_DEPS="zlib1g libbz2-1.0 libexpat1 libncurses5 libreadline7 tk libgdbm3 libdb5.3 libpcap0.8 liblzma5 libssl1.1 libkeyutils1 libkrb5-3 libcomerr2 libidn2-0 libcurl3 uuid libffi6"
else
	echo "Unsupported policy: '${AUDITWHEEL_POLICY}'"
	exit 1
fi


BASETOOLS="autoconf automake bison bzip2 diffutils file make patch unzip"
if [ "${AUDITWHEEL_POLICY}" == "manylinux2014" ]; then
	PACKAGE_MANAGER=yum
	BASETOOLS="${BASETOOLS} which"
	# See https://unix.stackexchange.com/questions/41784/can-yum-express-a-preference-for-x86-64-over-i386-packages
	echo "multilib_policy=best" >> /etc/yum.conf
	# Error out if requested packages do not exist
	echo "skip_missing_names_on_install=False" >> /etc/yum.conf
	# Make sure that locale will not be removed
	sed -i '/^override_install_langs=/d' /etc/yum.conf
	if [ "${AUDITWHEEL_ARCH}" == "s390x" ]; then
		# workaround for https://github.com/nealef/clefos/issues/5
		# this shall be removed ASAP
		yum -y install epel-release-7-12
		yum -y --exclude=epel-release update
	else
		yum -y update
	fi
	yum -y install yum-utils curl
	yum-config-manager --enable extras
	TOOLCHAIN_DEPS="devtoolset-9-binutils devtoolset-9-gcc devtoolset-9-gcc-c++ devtoolset-9-gcc-gfortran"
	if [ "${AUDITWHEEL_ARCH}" == "x86_64" ]; then
		# Software collection (for devtoolset-9)
		yum -y install centos-release-scl-rh
		# EPEL support (for yasm)
		yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
		TOOLCHAIN_DEPS="${TOOLCHAIN_DEPS} yasm"
	elif [ "${AUDITWHEEL_ARCH}" == "aarch64" ] || [ "${AUDITWHEEL_ARCH}" == "ppc64le" ] || [ "${AUDITWHEEL_ARCH}" == "s390x" ]; then
		# Software collection (for devtoolset-9)
		yum -y install centos-release-scl-rh
	elif [ "${AUDITWHEEL_ARCH}" == "i686" ]; then
		# No yasm on i686
		# Install mayeut/devtoolset-9 repo to get devtoolset-9
		curl -fsSLo /etc/yum.repos.d/mayeut-devtoolset-9.repo https://copr.fedorainfracloud.org/coprs/mayeut/devtoolset-9/repo/custom-1/mayeut-devtoolset-9-custom-1.repo
	fi
elif [ "${AUDITWHEEL_POLICY}" == "manylinux_2_24" ]; then
	PACKAGE_MANAGER=apt
	export DEBIAN_FRONTEND=noninteractive
	sed -i 's/none/en_US/g' /etc/apt/apt.conf.d/docker-no-languages
	apt-get update -qq
	apt-get upgrade -qq -y
	apt-get install -qq -y --no-install-recommends ca-certificates gpg curl locales
	TOOLCHAIN_DEPS="binutils gcc g++ gfortran"
fi

if ! which localedef &> /dev/null; then
	# somebody messed up glibc-common package to squeeze image size, reinstall the package
	if [ ${PACKAGE_MANAGER} == yum ]; then
		yum -y reinstall glibc-common
	else
		echo "Not implemented"
		exit 1
	fi
fi

# upgrading glibc-common can end with removal on en_US.UTF-8 locale
localedef -i en_US -f UTF-8 en_US.UTF-8

if [ ${PACKAGE_MANAGER} == yum ]; then
	yum -y install ${BASETOOLS} ${TOOLCHAIN_DEPS} ${MANYLINUX_DEPS} ${RUNTIME_DEPS}
	yum clean all
	rm -rf /var/cache/yum
elif [ ${PACKAGE_MANAGER} == apt ]; then
	apt-get install -qq -y --no-install-recommends ${BASETOOLS} ${TOOLCHAIN_DEPS} ${MANYLINUX_DEPS} ${RUNTIME_DEPS}
	apt-get clean -qq
	rm -rf /var/lib/apt/lists/*
else
	echo "Not implemented"
	exit 1
fi


# Fix libc headers to remain compatible with C99 compilers.
find /usr/include/ -type f -exec sed -i 's/\bextern _*inline_*\b/extern __inline __attribute__ ((__gnu_inline__))/g' {} +

if [ "${DEVTOOLSET_ROOTPATH:-}" != "" ]; then
    # remove useless things that have been installed by devtoolset
    rm -rf $DEVTOOLSET_ROOTPATH/usr/share/man
    find $DEVTOOLSET_ROOTPATH/usr/share/locale -mindepth 1 -maxdepth 1 -not \( -name 'en*' -or -name 'locale.alias' \) | xargs rm -rf
fi

rm -rf /usr/share/backgrounds

# if we updated glibc, we need to strip locales again...
if localedef --list-archive | grep -sq -v -i ^en_US.utf8; then
    localedef --list-archive | grep -v -i ^en_US.utf8 | xargs localedef --delete-from-archive
fi
if [ "${AUDITWHEEL_POLICY}" == "manylinux2014" ]; then
    mv -f /usr/lib/locale/locale-archive /usr/lib/locale/locale-archive.tmpl
    build-locale-archive
else
    rm /usr/lib/locale/locale-archive
    localedef -i en_US -f UTF-8 en_US.UTF-8
    update-locale LANG=en_US.UTF-8
fi

find /usr/share/locale -mindepth 1 -maxdepth 1 -not \( -name 'en*' -or -name 'locale.alias' \) | xargs rm -rf
if [ -d /usr/local/share/locale ]; then
    find /usr/local/share/locale -mindepth 1 -maxdepth 1 -not \( -name 'en*' -or -name 'locale.alias' \) | xargs rm -rf
fi
if [ -d /usr/local/share/man ]; then
    rm -rf /usr/local/share/man
fi

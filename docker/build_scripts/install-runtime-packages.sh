#!/bin/bash
# Install packages that will be needed at runtime

# Stop at any error, show all commands
set -exuo pipefail

# Set build environment variables
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Get build utilities
# shellcheck source-path=SCRIPTDIR
source "${MY_DIR}/build_utils.sh"

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
if [ "${OS_ID_LIKE}" == "rhel" ]; then
	MANYLINUX_DEPS=(glibc-devel libstdc++-devel glib2-devel libX11-devel libXext-devel libXrender-devel mesa-libGL-devel libICE-devel libSM-devel zlib-devel expat-devel)
elif [ "${OS_ID_LIKE}" == "debian" ]; then
  MANYLINUX_DEPS=(libc6-dev libglib2.0-dev libx11-dev libxext-dev libxrender-dev libgl1-mesa-dev libice-dev libsm-dev zlib1g-dev libexpat1-dev)
elif [ "${OS_ID_LIKE}" == "alpine" ]; then
	MANYLINUX_DEPS=(musl-dev libstdc++ glib-dev libx11-dev libxext-dev libxrender-dev mesa-dev libice-dev libsm-dev zlib-dev expat-dev)
else
	echo "Unsupported policy: '${AUDITWHEEL_POLICY}'"
	exit 1
fi

# RUNTIME_DEPS: Runtime dependencies. c.f. install-build-packages.sh
if [ "${OS_ID_LIKE}" == "rhel" ]; then
	RUNTIME_DEPS=(zlib bzip2 expat ncurses readline gdbm libpcap xz openssl keyutils-libs libkadm5 libcom_err libcurl uuid libffi libdb)
	if [ "${AUDITWHEEL_POLICY}" == "manylinux2014" ]; then
		RUNTIME_DEPS+=(libidn libXft)
	elif [ "${AUDITWHEEL_POLICY}" == "manylinux_2_28" ]; then
		RUNTIME_DEPS+=(libidn tk)
	else
		RUNTIME_DEPS+=(libidn2 tk)
		# for graalpy
		RUNTIME_DEPS+=(libxcrypt-compat)
	fi
elif [ "${OS_ID_LIKE}" == "debian" ]; then
  RUNTIME_DEPS=(zlib1g libbz2-1.0 libexpat1 libncurses6 libreadline8 tk libgdbm6 libdb5.3 libpcap0.8 liblzma5 libkeyutils1 libkrb5-3 libcom-err2 libidn2-0 libcurl4 uuid)
  if [ "${AUDITWHEEL_POLICY}" == "manylinux_2_31" ]; then
  	RUNTIME_DEPS+=(libffi7 libssl1.1)
  else
  	RUNTIME_DEPS+=(libffi8 libssl3)
  fi
elif [ "${OS_ID_LIKE}" == "alpine" ]; then
	RUNTIME_DEPS=(zlib bzip2 expat ncurses-libs readline tk gdbm db xz openssl keyutils-libs krb5-libs libcom_err libidn2 libcurl libuuid libffi)
else
	echo "Unsupported policy: '${AUDITWHEEL_POLICY}'"
	exit 1
fi

BASE_TOOLS=(autoconf automake bison bzip2 ca-certificates curl diffutils file make patch unzip)
if [ "${AUDITWHEEL_POLICY}" == "manylinux2014" ]; then
	BASE_TOOLS+=(hardlink hostname which)
	# See https://unix.stackexchange.com/questions/41784/can-yum-express-a-preference-for-x86-64-over-i386-packages
	echo "multilib_policy=best" >> /etc/yum.conf
	# Error out if requested packages do not exist
	echo "skip_missing_names_on_install=False" >> /etc/yum.conf
	# Make sure that locale will not be removed
	sed -i '/^override_install_langs=/d' /etc/yum.conf

	# we don't need those in the first place & updates are taking a lot of space on aarch64
	# the intent is in the upstream image creation but it got messed up at some point
	# https://github.com/CentOS/sig-cloud-instance-build/blob/98aa8c6f0290feeb94d86b52c561d70eabc7d942/docker/centos-7-x86_64.ks#L43
	if rpm -q kernel-modules; then
		rpm -e kernel-modules
	fi
	if rpm -q kernel-core; then
		rpm -e --noscripts kernel-core
	fi
	if rpm -q bind-license; then
		yum -y erase bind-license qemu-guest-agent
	fi
	fixup-mirrors
	yum -y update
	fixup-mirrors
	yum -y install yum-utils curl
	yum-config-manager --enable extras
	TOOLCHAIN_DEPS=(devtoolset-10-binutils devtoolset-10-gcc devtoolset-10-gcc-c++ devtoolset-10-gcc-gfortran devtoolset-10-libatomic-devel)
	if [ "${AUDITWHEEL_ARCH}" == "x86_64" ]; then
		# Software collection (for devtoolset-10)
		yum -y install centos-release-scl-rh
		if ! rpm -q epel-release-7-14.noarch; then
			# EPEL support (for yasm)
			yum -y install https://archives.fedoraproject.org/pub/archive/epel/7/x86_64/Packages/e/epel-release-7-14.noarch.rpm
		fi
		TOOLCHAIN_DEPS+=(yasm)
	elif [ "${AUDITWHEEL_ARCH}" == "aarch64" ] || [ "${AUDITWHEEL_ARCH}" == "ppc64le" ] || [ "${AUDITWHEEL_ARCH}" == "s390x" ]; then
		# Software collection (for devtoolset-10)
		yum -y install centos-release-scl-rh
	elif [ "${AUDITWHEEL_ARCH}" == "i686" ]; then
		# No yasm on i686
		# Install mayeut/devtoolset-10 repo to get devtoolset-10
		curl -fsSLo /etc/yum.repos.d/mayeut-devtoolset-10.repo https://copr.fedorainfracloud.org/coprs/mayeut/devtoolset-10/repo/custom-1/mayeut-devtoolset-10-custom-1.repo
	fi
	fixup-mirrors
elif [ "${OS_ID_LIKE}" == "rhel" ]; then
	BASE_TOOLS+=(glibc-locale-source glibc-langpack-en hardlink hostname libcurl libnsl libxcrypt which)
	echo "tsflags=nodocs" >> /etc/dnf/dnf.conf
	dnf -y upgrade
	EPEL=epel-release
	if [ "${AUDITWHEEL_ARCH}" == "i686" ]; then
		EPEL=
	fi
	dnf -y install dnf-plugins-core ${EPEL}
	if [ "${AUDITWHEEL_POLICY}" == "manylinux_2_28" ]; then
		dnf config-manager --set-enabled powertools
	else
		dnf config-manager --set-enabled crb
	fi
	TOOLCHAIN_DEPS=(gcc-toolset-14-binutils gcc-toolset-14-gcc gcc-toolset-14-gcc-c++ gcc-toolset-14-gcc-gfortran gcc-toolset-14-libatomic-devel)
	if [ "${AUDITWHEEL_ARCH}" == "x86_64" ]; then
		TOOLCHAIN_DEPS+=(yasm)
	fi
elif [ "${OS_ID_LIKE}" == "debian" ]; then
	TOOLCHAIN_DEPS+=(binutils gcc g++ gfortran libatomic1)
	BASE_TOOLS+=(gpg gpg-agent hardlink hostname locales xz-utils)
elif [ "${OS_ID_LIKE}" == "alpine" ]; then
	TOOLCHAIN_DEPS=(binutils gcc g++ gfortran libatomic)
	BASE_TOOLS+=(gnupg util-linux shadow tar)
else
	echo "Unsupported policy: '${AUDITWHEEL_POLICY}'"
	exit 1
fi

manylinux_pkg_install "${BASE_TOOLS[@]}" "${TOOLCHAIN_DEPS[@]}" "${MANYLINUX_DEPS[@]}" "${RUNTIME_DEPS[@]}"

# update system packages, we already updated them but
# the following script takes care of cleaning-up some things
# and since it's also needed in the finalize step, everything's
# centralized in this script to avoid code duplication
LC_ALL=C "${MY_DIR}/update-system-packages.sh"

if [ "${BASE_POLICY}" == "manylinux" ]; then
	# we'll be removing libcrypt.so.1 later on
	# this is needed to ensure the new one will be found
	# as LD_LIBRARY_PATH does not seem enough.
	# c.f. https://github.com/pypa/manylinux/issues/1022
	echo "/usr/local/lib" > /etc/ld.so.conf.d/00-manylinux.conf
	ldconfig
else
	# set the default shell to bash
	chsh -s /bin/bash root
	useradd -D -s /bin/bash
fi

if [ "${OS_ID_LIKE}-${AUDITWHEEL_ARCH}" == "rhel-i686" ] && [ -f /usr/bin/i686-redhat-linux-gnu-pkg-config ] && [ ! -f /usr/bin/i386-redhat-linux-gnu-pkg-config ]; then
	ln -s i686-redhat-linux-gnu-pkg-config /usr/bin/i386-redhat-linux-gnu-pkg-config
fi

#!/bin/bash
# Top-level build script called from Dockerfile

# Stop at any error, show all commands
set -exuo pipefail

# Set build environment variables
MY_DIR=$(dirname "${BASH_SOURCE[0]}")
. $MY_DIR/build_env.sh

# Load OS information
. /etc/os-release

# Dependencies for compiling Python that we want to remove from
# the final image after compiling Python
if [ "${ID}" == "centos" ]; then
    PYTHON_COMPILE_DEPS="zlib-devel bzip2-devel expat-devel ncurses-devel readline-devel tk-devel gdbm-devel libdb-devel libpcap-devel xz-devel openssl-devel keyutils-libs-devel krb5-devel libcom_err-devel libidn-devel curl-devel perl-devel"
elif [ "${ID}" == "debian" ]; then
    PYTHON_COMPILE_DEPS="libz-dev libbz2-dev libexpat-dev ncurses-dev libreadline-dev tk-dev libgdbm-dev libdb-dev libpcap-dev liblzma-dev libssl-dev libkeyutils-dev libkrb5-dev comerr-dev libidn2-0-dev libcurl4-openssl-dev libperl-dev uuid-dev"
else
    echo "Unsupported OS: ${ID}">2
    exit 1
fi

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
if [ "${ID}" == "centos" ]; then
    MANYLINUX_DEPS="glibc-devel libstdc++-devel glib2-devel libX11-devel libXext-devel libXrender-devel mesa-libGL-devel libICE-devel libSM-devel"
elif [ "${ID}" == "debian" ]; then
    MANYLINUX_DEPS="libc6-dev libstdc++-6-dev libglib2.0-dev libx11-dev libxext-dev libxrender-dev libgl1-mesa-dev libice-dev libsm-dev"
fi

# Get build utilities
source $MY_DIR/build_utils.sh

if [ "${ID}" == "centos" ]; then
    # See https://unix.stackexchange.com/questions/41784/can-yum-express-a-preference-for-x86-64-over-i386-packages
    echo "multilib_policy=best" >> /etc/yum.conf
    # Error out if requested packages do not exist
    echo "skip_missing_names_on_install=False" >> /etc/yum.conf
    # Make sure that locale will not be removed
    sed -i '/^override_install_langs=/d' /etc/yum.conf
fi

# https://hub.docker.com/_/centos/
# "Additionally, images with minor version tags that correspond to install
# media are also offered. These images DO NOT recieve updates as they are
# intended to match installation iso contents. If you choose to use these
# images it is highly recommended that you include RUN yum -y update && yum
# clean all in your Dockerfile, or otherwise address any potential security
# concerns."
# Decided not to clean at this point: https://github.com/pypa/manylinux/pull/129
if [ "${ID}" == "centos" ]; then
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

    if ! which localedef &> /dev/null; then
        # somebody messed up glibc-common package to squeeze image size, reinstall the package
        yum -y reinstall glibc-common
    fi
elif [ "${ID}" == "debian" ]; then
    export DEBIAN_FRONTEND=noninteractive
    sed -i 's/none/en_US/g' /etc/apt/apt.conf.d/docker-no-languages
    apt-get update -qq
    apt-get upgrade -qq -y
    apt-get install -qq -y --no-install-recommends ca-certificates gpg curl locales
fi

# upgrading glibc-common can end with removal on en_US.UTF-8 locale
localedef -i en_US -f UTF-8 en_US.UTF-8

YASM=
if [ "${ID}" == "centos" ]; then
    TOOLCHAIN_DEPS="devtoolset-9-binutils devtoolset-9-gcc devtoolset-9-gcc-c++ devtoolset-9-gcc-gfortran"
    if [ "${AUDITWHEEL_ARCH}" == "x86_64" ]; then
        # Software collection (for devtoolset-9)
        yum -y install centos-release-scl-rh
        # EPEL support (for yasm)
        yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
        YASM=yasm
    elif [ "${AUDITWHEEL_ARCH}" == "aarch64" ] || [ "${AUDITWHEEL_ARCH}" == "ppc64le" ] || [ "${AUDITWHEEL_ARCH}" == "s390x" ]; then
        # Software collection (for devtoolset-9)
        yum -y install centos-release-scl-rh
    elif [ "${AUDITWHEEL_ARCH}" == "i686" ]; then
        # No yasm on i686
        # Install mayeut/devtoolset-9 repo to get devtoolset-9
        curl -fsSLo /etc/yum.repos.d/mayeut-devtoolset-9.repo https://copr.fedorainfracloud.org/coprs/mayeut/devtoolset-9/repo/custom-1/mayeut-devtoolset-9-custom-1.repo
    fi
elif [ "${ID}" == "debian" ]; then
    TOOLCHAIN_DEPS="binutils gcc g++ gfortran"
fi


# Development tools and libraries
if [ "${ID}" == "centos" ]; then
    yum -y install \
        autoconf \
        automake \
        bison \
        bzip2 \
        ${TOOLCHAIN_DEPS} \
        diffutils \
        gettext \
        file \
        kernel-devel \
        libffi-devel \
        make \
        patch \
        unzip \
        which \
        ${YASM} \
        ${PYTHON_COMPILE_DEPS}
elif [ "${ID}" == "debian" ]; then
    apt-get install -qq -y --no-install-recommends \
        autoconf \
        automake \
        bison \
        bzip2 \
        ${TOOLCHAIN_DEPS} \
        diffutils \
        gettext \
        file \
        linux-kernel-headers \
        libffi-dev \
        make \
        patch \
        unzip \
        ${YASM} \
        ${PYTHON_COMPILE_DEPS}
fi

# Install git
build_git $GIT_ROOT $GIT_HASH
git version

# Install newest automake
build_automake $AUTOMAKE_ROOT $AUTOMAKE_HASH
automake --version

# Install newest libtool
build_libtool $LIBTOOL_ROOT $LIBTOOL_HASH
libtool --version

# Install a more recent SQLite3
curl -fsSLO $SQLITE_AUTOCONF_DOWNLOAD_URL/$SQLITE_AUTOCONF_VERSION.tar.gz
check_sha256sum $SQLITE_AUTOCONF_VERSION.tar.gz $SQLITE_AUTOCONF_HASH
tar xfz $SQLITE_AUTOCONF_VERSION.tar.gz
cd $SQLITE_AUTOCONF_VERSION
do_standard_install
cd ..
rm -rf $SQLITE_AUTOCONF_VERSION*
rm /usr/local/lib/libsqlite3.a

# Install a recent version of cmake3
curl -L -O $CMAKE_DOWNLOAD_URL/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}.tar.gz
check_sha256sum cmake-${CMAKE_VERSION}.tar.gz $CMAKE_HASH
tar -xzf cmake-${CMAKE_VERSION}.tar.gz
cd cmake-${CMAKE_VERSION}
./bootstrap --system-curl --parallel=$(nproc)
make -j$(nproc)
make install
cd ..
rm -rf cmake-${CMAKE_VERSION}

# Install libcrypt.so.1 and libcrypt.so.2
build_libxcrypt "$LIBXCRYPT_DOWNLOAD_URL" "$LIBXCRYPT_VERSION" "$LIBXCRYPT_HASH"

# Compile the latest Python releases.
# (In order to have a proper SSL module, Python is compiled
# against a recent openssl [see env vars above], which is linked
# statically.
mkdir -p /opt/python
build_cpythons $CPYTHON_VERSIONS

# Create venv for auditwheel & certifi
TOOLS_PATH=/opt/_internal/tools
/opt/python/cp37-cp37m/bin/python -m venv $TOOLS_PATH
source $TOOLS_PATH/bin/activate

# Install default packages
pip install -U --require-hashes -r $MY_DIR/requirements.txt
# Install certifi and auditwheel
pip install -U --require-hashes -r $MY_DIR/requirements-tools.txt

# Make auditwheel available in PATH
ln -s $TOOLS_PATH/bin/auditwheel /usr/local/bin/auditwheel

# Our openssl doesn't know how to find the system CA trust store
#   (https://github.com/pypa/manylinux/issues/53)
# And it's not clear how up-to-date that is anyway
# So let's just use the same one pip and everyone uses
ln -s $(python -c 'import certifi; print(certifi.where())') /opt/_internal/certs.pem
# If you modify this line you also have to modify the versions in the Dockerfiles:
export SSL_CERT_FILE=/opt/_internal/certs.pem

# Deactivate the tools virtual environment
deactivate

# Install patchelf (latest with unreleased bug fixes) and apply our patches
build_patchelf $PATCHELF_VERSION $PATCHELF_HASH

# Clean up development headers and other unnecessary stuff for
# final image
if [ "${ID}" == "centos" ]; then
    yum -y erase \
        avahi \
        bitstream-vera-fonts \
        freetype \
        gettext \
        gtk2 \
        hicolor-icon-theme \
        libX11 \
        wireless-tools \
        ${PYTHON_COMPILE_DEPS} > /dev/null 2>&1
    yum -y install ${MANYLINUX_DEPS}
    yum -y clean all > /dev/null 2>&1
    yum list installed
elif [ "${ID}" == "debian" ]; then
    rm -rf /var/lib/apt/lists/*
fi

# we don't need libpython*.a, and they're many megabytes
find /opt/_internal -name '*.a' -print0 | xargs -0 rm -f

# Strip what we can -- and ignore errors, because this just attempts to strip
# *everything*, including non-ELF files:
find /opt/_internal -type f -print0 \
    | xargs -0 -n1 strip --strip-unneeded 2>/dev/null || true
find /usr/local -type f -print0 \
    | xargs -0 -n1 strip --strip-unneeded 2>/dev/null || true

for PYTHON in /opt/python/*/bin/python; do
    # Smoke test to make sure that our Pythons work, and do indeed detect as
    # being manylinux compatible:
    $PYTHON $MY_DIR/manylinux-check.py
    # Make sure that SSL cert checking works
    $PYTHON $MY_DIR/ssl-check.py
done

# We do not need the Python test suites, or indeed the precompiled .pyc and
# .pyo files. Partially cribbed from:
#    https://github.com/docker-library/python/blob/master/3.4/slim/Dockerfile
find /opt/_internal -depth \
     \( -type d -a -name test -o -name tests \) \
  -o \( -type f -a -name '*.pyc' -o -name '*.pyo' \) | xargs rm -rf

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
if [ "${ID}" == "centos" ]; then
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

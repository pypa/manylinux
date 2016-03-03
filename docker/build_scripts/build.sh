#!/bin/bash
# Top-level build script called from Dockerfile

# Stop at any error, show all commands
set -ex

# Python versions to be installed in /opt/$VERSION_NO
PY_VERS="2.6.9 2.7.11 3.3.6 3.4.4 3.5.1"

# openssl version to build, with expected sha256 hash of .tar.gz
# archive
OPENSSL_ROOT=openssl-1.0.2g
OPENSSL_HASH=b784b1b3907ce39abf4098702dade6365522a253ad1552e267a9a0e89594aa33

# Dependencies for compiling Python that we want to remove from
# the final image after compiling Python
PYTHON_COMPILE_DEPS="zlib-devel bzip2-devel ncurses-devel sqlite-devel readline-devel tk-devel gdbm-devel db4-devel libpcap-devel xz-devel"

# Libraries that are allowed as part of the manylinux1 profile
MANYLINUX1_DEPS="glibc-devel libstdc++-devel glib2-devel libX11-devel libXext-devel libXrender-devel  mesa-libGL-devel libICE-devel libSM-devel ncurses-devel"

# Get build utilities
MY_DIR=$(dirname "$BASH_SOURCE[0]}")
source $MY_DIR/build_utils.sh

# EPEL support
yum -y install wget curl
curl -sLO https://dl.fedoraproject.org/pub/epel/5/x86_64/epel-release-5-4.noarch.rpm
# Dev toolset (for LLVM and other projects requiring C++11 support)
curl -sL http://people.centos.org/tru/devtools-2/devtools-2.repo > /etc/yum.repos.d/devtools-2.repo
rpm -Uvh --replacepkgs epel-release-5*.rpm
rm -f epel-release-5*.rpm

# Development tools and libraries
yum -y install bzip2 make git patch unzip bison yasm diffutils \
    autoconf automake which file \
    kernel-devel-`uname -r` \
    devtoolset-2-binutils devtoolset-2-gcc \
    devtoolset-2-gcc-c++ devtoolset-2-gcc-gfortran \
    ${PYTHON_COMPILE_DEPS}

# Compile the latest Python releases.
# (In order to have a proper SSL module, Python is compiled
# against a recent openssl [see env vars above], which is linked
# statically. We delete openssl afterwards.)
build_openssl $OPENSSL_ROOT $OPENSSL_HASH
build_pythons $PY_VERS
rm -rf /usr/local/ssl

# Install patchelf and auditwheel (latest)
curl -sLO http://nixos.org/releases/patchelf/patchelf-0.8/patchelf-0.8.tar.gz
tar -xzf patchelf-0.8.tar.gz
(cd patchelf-0.8 && ./configure && make && make install)
rm -rf patchelf-0.8.tar.gz patchelf-0.8

/opt/3.5/bin/pip install git+git://github.com/manylinux/auditwheel.git && \
ln -s /opt/3.5/bin/auditwheel /usr/local/bin/auditwheel

# Clean up development headers and other unnecessary stuff for
# final image
yum -y erase wireless-tools gtk2 libX11 hicolor-icon-theme \
    avahi freetype bitstream-vera-fonts \
    ${PYTHON_COMPILE_DEPS}  > /dev/null 2>&1
yum -y install ${MANYLINUX1_DEPS}
yum -y clean all > /dev/null 2>&1
yum list installed

for PYVER in $PY_VERS; do
    /opt/$PYVER/bin/python $MY_DIR/manylinux1-check.py
done

#!/bin/bash
# Top-level build script called from Dockerfile

# Stop at any error, show all commands
set -ex

# Set build environment variables
MY_DIR=$(dirname "${BASH_SOURCE[0]}")
source $MY_DIR/build_env.sh

# Get build utilities
source $MY_DIR/build_utils.sh

# Dependencies for compiling Python that we want to remove from
# the final image after compiling Python
PYTHON_COMPILE_DEPS="zlib-devel bzip2-devel expat-devel ncurses-devel readline-devel tk-devel gdbm-devel libdb-devel libpcap-devel xz-devel openssl-devel keyutils-libs-devel krb5-devel libcom_err-devel libidn-devel curl-devel perl-devel libffi-devel kernel-devel"
CMAKE_DEPS="openssl-devel zlib-devel libcurl-devel"

# Development tools and libraries
yum -y install ${PYTHON_COMPILE_DEPS} ${CMAKE_DEPS}

# Install git
build_git $GIT_ROOT $GIT_HASH
/manylinux-rootfs/usr/local/bin/git version

# Install a more recent SQLite3
curl -fsSLO $SQLITE_AUTOCONF_DOWNLOAD_URL/$SQLITE_AUTOCONF_ROOT.tar.gz
check_sha256sum $SQLITE_AUTOCONF_ROOT.tar.gz $SQLITE_AUTOCONF_HASH
tar xfz $SQLITE_AUTOCONF_ROOT.tar.gz
cd $SQLITE_AUTOCONF_ROOT
DESTDIR=/sqlite3 do_standard_install
cd ..
rm -rf $SQLITE_AUTOCONF_ROOT*
rm /sqlite3/usr/local/lib/libsqlite3.a
# Install for build
cp -rf /sqlite3/* /
# Clean-up for runtime
rm -rf /sqlite3/usr/local/bin /sqlite3/usr/local/include /sqlite3/usr/local/lib/pkg-config /sqlite3/usr/local/share
# Install for runtime
cp -rf /sqlite3/* /manylinux-rootfs/
# clean-up
rm -rf /sqlite3

# Install a recent version of cmake3
curl -L -O $CMAKE_DOWNLOAD_URL/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}.tar.gz
check_sha256sum cmake-${CMAKE_VERSION}.tar.gz $CMAKE_HASH
tar -xzf cmake-${CMAKE_VERSION}.tar.gz
cd cmake-${CMAKE_VERSION}
./bootstrap --system-curl --parallel=$(nproc)
make -j$(nproc)
make install DESTDIR=/manylinux-rootfs
cd ..
rm -rf cmake-${CMAKE_VERSION}*

# Compile the latest Python releases.
# (In order to have a proper SSL module, Python is compiled
# against a recent openssl [see env vars above], which is linked
# statically.
build_cpythons $CPYTHON_VERSIONS

# we don't need libpython*.a, and they're many megabytes
find /opt/_internal -name '*.a' -print0 | xargs -0 rm -f

# Strip what we can -- and ignore errors, because this just attempts to strip
# *everything*, including non-ELF files:
find /opt/_internal -type f -print0 \
    | xargs -0 -n1 strip --strip-unneeded 2>/dev/null || true
find /manylinux-rootfs -type f -print0 \
    | xargs -0 -n1 strip --strip-unneeded 2>/dev/null || true

# We do not need the Python test suites, or indeed the precompiled .pyc and
# .pyo files. Partially cribbed from:
#    https://github.com/docker-library/python/blob/master/3.4/slim/Dockerfile
find /opt/_internal -depth \
     \( -type d -a -name test -o -name tests \) \
  -o \( -type f -a -name '*.pyc' -o -name '*.pyo' \) | xargs rm -rf

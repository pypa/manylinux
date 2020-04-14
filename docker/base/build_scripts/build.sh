#!/bin/bash

set -ex

MY_DIR=$(dirname "${BASH_SOURCE[0]}")
. $MY_DIR/build_env.sh

BASE_DEPS="\
    bzip2 \
    diffutils \
    file \
    gettext \
    glibc-devel \
    glibc-devel.i386 \
    kernel-devel-`uname -r` \
    make \
    patch \
    texinfo \
    unzip \
    wget \
    which \
    yasm \
    "
GCC_COMPILE_DEPS="\
    gcc \
    gcc-c++ \
    libgcc.i386 \
    libstdc++-devel \
    libstdc++-devel.i386 \
    zlib-devel \
    "

source $MY_DIR/build_helpers.sh

# Centos 5 is EOL and is no longer available from the usual mirrors, so switch
# to http://vault.centos.org
# From: https://github.com/rust-lang/rust/pull/41045
# The location for version 5 was also removed, so now only the specific release
# (5.11) can be referenced.
sed -i 's/enabled=1/enabled=0/' /etc/yum/pluginconf.d/fastestmirror.conf
sed -i 's/mirrorlist/#mirrorlist/' /etc/yum.repos.d/*.repo
sed -i 's/#\(baseurl.*\)mirror.centos.org\/centos\/$releasever/\1vault.centos.org\/5.11/' /etc/yum.repos.d/*.repo

# See https://unix.stackexchange.com/questions/41784/can-yum-express-a-preference-for-x86-64-over-i386-packages
echo "multilib_policy=best" >> /etc/yum.conf

# https://hub.docker.com/_/centos/
# "Additionally, images with minor version tags that correspond to install
# media are also offered. These images DO NOT recieve updates as they are
# intended to match installation iso contents. If you choose to use these
# images it is highly recommended that you include RUN yum -y update && yum
# clean all in your Dockerfile, or otherwise address any potential security
# concerns."
# Decided not to clean at this point: https://github.com/pypa/manylinux/pull/129
yum -y update

yum -y install $BASE_DEPS $GCC_COMPILE_DEPS

pkg_fetch gcc $GCC_DOWNLOAD_URL $GCC_HASH
pkg_fetch binutils $BINUTILS_DOWNLOAD_URL $BINUTILS_HASH
pkg_fetch gdb $GDB_DOWNLOAD_URL $GDB_HASH

export \
    CFLAGS="-pipe -ffunction-sections -fdata-sections" \
    LDFLAGS="-Wl,--gc-sections -Wl,-z,noexecstack"

pkg_enter gcc
contrib/download_prerequisites
mkdir build
cd build
gcc_target_platform=$(rpm --eval '%{_target_platform}')
../configure \
    --prefix=$DEVTOOLS_PREFIX \
    --build=$gcc_target_platform \
    --host=$gcc_target_platform \
    --target=$gcc_target_platform \
    --with-cpu=generic \
    --enable-shared \
    --enable-threads=posix \
    --enable-checking=release \
    --with-system-zlib \
    --enable-__cxa_atexit \
    --disable-libunwind-exceptions \
    --enable-languages=c,c++
make -j$CORES
make install-strip
pkg_leave

export \
    PATH="$DEVTOOLS_PREFIX/bin:$PATH" \
    CPP="$DEVTOOLS_PREFIX/bin/cpp" \
    CC="$DEVTOOLS_CC -static-libgcc" \
    CXX="$DEVTOOLS_CXX -static-libgcc -static-libstdc++"

pkg_enter binutils
./configure \
    --prefix=$DEVTOOLS_PREFIX \
    --enable-gold
make -j$CORES
make install-strip
pkg_leave

export \
    CC="$DEVTOOLS_CC -static-libgcc -fuse-ld=gold" \
    CXX="$DEVTOOLS_CXX -static-libgcc -static-libstdc++ -fuse-ld=gold" \
    LD="$DEVTOOLS_PREFIX/bin/ld.gold" \
    AR="$DEVTOOLS_PREFIX/bin/ar" \
    NM="$DEVTOOLS_PREFIX/bin/nm" \
    RANLIB="$DEVTOOLS_PREFIX/bin/ranlib" \
    STRIP="$DEVTOOLS_PREFIX/bin/strip" \
    OBJCOPY="$DEVTOOLS_PREFIX/bin/objcopy" \
    OBJDUMP="$DEVTOOLS_PREFIX/bin/objdump" \
    LDFLAGS="$LDFLAGS -Wl,--icf=all"

pkg_enter gdb
mkdir build
cd build
../configure --prefix=$DEVTOOLS_PREFIX
while ! make -j$CORES; do
    make -j$CORES || true
    make || true
done
make install
strip --strip-all $DEVTOOLS_PREFIX/bin/gdb
pkg_leave

yum -y erase $GCC_COMPILE_DEPS
rm -rf $DEVTOOLS_PREFIX/share/

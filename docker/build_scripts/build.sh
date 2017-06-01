#!/bin/bash
# Top-level build script called from Dockerfile

# Stop at any error, show all commands
set -ex

# Python versions to be installed in /opt/$VERSION_NO
CPYTHON_VERSIONS="2.7.12 3.5.2 3.6.0"

# openssl version to build, with expected sha256 hash of .tar.gz
# archive
OPENSSL_ROOT=openssl-1.0.2k
OPENSSL_HASH=6b3977c61f2aedf0f96367dcfb5c6e578cf37e7b8d913b4ecb6643c3cb88d8c0
EPEL_RPM_HASH=0dcc89f9bf67a2a515bad64569b7a9615edc5e018f676a578d5fd0f17d3c81d4
DEVTOOLS_HASH=a8ebeb4bed624700f727179e6ef771dafe47651131a00a78b342251415646acc
PATCHELF_HASH=d9afdff4baeacfbc64861454f368b7f2c15c44d245293f7587bbf726bfe722fb
CURL_ROOT=curl-7.49.1
CURL_HASH=eb63cec4bef692eab9db459033f409533e6d10e20942f4b060b32819e81885f1
AUTOCONF_ROOT=autoconf-2.69
AUTOCONF_HASH=954bd69b391edc12d6a4a51a2dd1476543da5c6bbf05a95b59dc0dd6fd4c2969

# Dependencies for compiling Python that we want to remove from
# the final image after compiling Python
PYTHON_COMPILE_DEPS="zlib-devel bzip2-devel ncurses-devel sqlite-devel \
                     readline-devel tk-devel gdbm-devel db4-devel libpcap-devel\
                     xz-devel atlas-devel libev-devel libev snappy-devel
                     python-imaging openjpeg-devel freetype-devel libpng-devel \
                     libffi-devel python-lxml postgresql95-libs \
                     postgresql95-devel lapack-devel python \
                     python-devel python-setuptools pcre pcre-devel"

# Libraries that are allowed as part of the manylinux1 profile
MANYLINUX1_DEPS="glibc-devel libstdc++-devel glib2-devel libX11-devel libXext-devel libXrender-devel  mesa-libGL-devel libICE-devel libSM-devel ncurses-devel libxmlsec1-devel"

# Centos 5 is EOL and is no longer available from the usual mirrors, so switch
# to http://vault.centos.org
# From: https://github.com/rust-lang/rust/pull/41045
# IP 107.158.252.35 is one of several DNS resolutions for vault.centos.org.
sed -i 's/enabled=1/enabled=0/' /etc/yum/pluginconf.d/fastestmirror.conf
sed -i 's/mirrorlist/#mirrorlist/' /etc/yum.repos.d/*.repo
sed -i 's/#\(baseurl.*\)mirror.centos.org\/centos\/$releasever/\1vault.centos.org\/5.11/' /etc/yum.repos.d/*.repo

# Get build utilities
MY_DIR=$(dirname "${BASH_SOURCE[0]}")
source $MY_DIR/build_utils.sh

# EPEL support
yum -y install wget curl
#curl -sLO https://dl.fedoraproject.org/pub/epel/5/x86_64/epel-release-5-4.noarch.rpm
cp $MY_DIR/epel-release-5-4.noarch.rpm .
check_sha256sum epel-release-5-4.noarch.rpm $EPEL_RPM_HASH

# Dev toolset (for LLVM and other projects requiring C++11 support)
curl -sLO http://people.centos.org/tru/devtools-2/devtools-2.repo
check_sha256sum devtools-2.repo $DEVTOOLS_HASH
mv devtools-2.repo /etc/yum.repos.d/devtools-2.repo
rpm -Uvh --replacepkgs epel-release-5*.rpm
rm -f epel-release-5*.rpm

# Setup postgresql repo
sed -r -i 's/\[(base|update)\]/[\1]\nexclude=postgresql*\n/g' /etc/yum.repos.d/CentOS-Base.repo
curl -SLO https://download.postgresql.org/pub/repos/yum/9.5/redhat/rhel-5-x86_64/pgdg-centos95-9.5-3.noarch.rpm
rpm -Uvh --replacepkgs pgdg-centos*.rpm
rm -f pgdg-centos*.rpm
yum list postgres*

# Development tools and libraries
yum -y install bzip2 make git patch unzip bison yasm diffutils \
    automake which file cmake28 \
    kernel-devel-`uname -r` \
    devtoolset-2-binutils devtoolset-2-gcc \
    devtoolset-2-gcc-c++ devtoolset-2-gcc-gfortran \
    ${PYTHON_COMPILE_DEPS}

# Install newest autoconf
build_autoconf $AUTOCONF_ROOT $AUTOCONF_HASH
autoconf --version

# Compile the latest Python releases.
# (In order to have a proper SSL module, Python is compiled
# against a recent openssl [see env vars above], which is linked
# statically.)
build_openssl $OPENSSL_ROOT $OPENSSL_HASH
mkdir -p /opt/python
build_cpythons $CPYTHON_VERSIONS

PY36_BIN=/opt/python/cp36-cp36m/bin

# Our openssl doesn't know how to find the system CA trust store
#   (https://github.com/pypa/manylinux/issues/53)
# And it's not clear how up-to-date that is anyway
# So let's just use the same one pip and everyone uses
$PY36_BIN/pip install certifi
ln -s $($PY36_BIN/python -c 'import certifi; print(certifi.where())') \
      /opt/_internal/certs.pem
# If you modify this line you also have to modify the versions in the
# Dockerfiles:
export SSL_CERT_FILE=/opt/_internal/certs.pem

# Install newest curl
build_curl $CURL_ROOT $CURL_HASH
rm -rf /usr/local/include/curl /usr/local/lib/libcurl* /usr/local/lib/pkgconfig/libcurl.pc
hash -r
curl --version
curl-config --features

# Install patchelf (latest with unreleased bug fixes)
curl -sLO https://nipy.bic.berkeley.edu/manylinux/patchelf-0.9njs2.tar.gz
check_sha256sum patchelf-0.9njs2.tar.gz $PATCHELF_HASH
tar -xzf patchelf-0.9njs2.tar.gz
(cd patchelf-0.9njs2 && ./configure && make && make install)
rm -rf patchelf-0.9njs2.tar.gz patchelf-0.9njs2

# Build/install latest libxml and libxsl
wget http://xmlsoft.org/sources/libxml2-2.9.4.tar.gz
wget http://xmlsoft.org/sources/libxslt-1.1.29.tar.gz
echo 'ae249165c173b1ff386ee8ad676815f5  libxml2-2.9.4.tar.gz' > md5sums
echo 'a129d3c44c022de3b9dcf6d6f288d72e  libxslt-1.1.29.tar.gz' >> md5sums
md5sum -c md5sums
tar -xzf libxml2-2.9.4.tar.gz
tar -xzf libxslt-1.1.29.tar.gz
(cd libxml2-2.9.4 && sed -i "/seems to be moved/s/^/#/" ltmain.sh && ./configure --prefix=/usr --with-history --with-python=$PY35_BIN/python && make && make install)
(cd libxslt-1.1.29 && sed -i "/seems to be moved/s/^/#/" ltmain.sh && ./configure --prefix=/usr --with-history && make && make install)

# Install latest pypi release of auditwheel
$PY36_BIN/pip install auditwheel
ln -s $PY36_BIN/auditwheel /usr/local/bin/auditwheel

# Clean up development headers and other unnecessary stuff for
# final image
yum -y erase wireless-tools gtk2 libX11 hicolor-icon-theme \
    avahi freetype bitstream-vera-fonts > /dev/null 2>&1
yum -y install ${MANYLINUX1_DEPS}
yum -y clean all > /dev/null 2>&1
yum list installed
# we don't need libpython*.a, and they're many megabytes
find /opt/_internal -name '*.a' -print0 | xargs -0 rm -f
# Strip what we can -- and ignore errors, because this just attempts to strip
# *everything*, including non-ELF files:
find /opt/_internal -type f -print0 \
    | xargs -0 -n1 strip --strip-unneeded 2>/dev/null || true
# We do not need the Python test suites, or indeed the precompiled .pyc and
# .pyo files. Partially cribbed from:
#    https://github.com/docker-library/python/blob/master/3.4/slim/Dockerfile
find /opt/_internal \
     \( -type d -a -name test -o -name tests \) \
  -o \( -type f -a -name '*.pyc' -o -name '*.pyo' \) \
  -print0 | xargs -0 rm -f

for PYTHON in /opt/python/*/bin/python; do
    # Smoke test to make sure that our Pythons work, and do indeed detect as
    # being manylinux compatible:
    $PYTHON $MY_DIR/manylinux1-check.py
    # Make sure that SSL cert checking works
    $PYTHON $MY_DIR/ssl-check.py
done

# Fix libc headers to remain compatible with C99 compilers.
find /usr/include/ -type f -exec sed -i 's/\bextern _*inline_*\b/extern __inline __attribute__ ((__gnu_inline__))/g' {} +

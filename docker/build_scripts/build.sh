#!/bin/bash
# Top-level build script called from Dockerfile

# Stop at any error, show all commands
set -ex

# Set build environment variables
MY_DIR=$(dirname "${BASH_SOURCE[0]}")
. $MY_DIR/build_env.sh

# Dependencies for compiling Python that we want to remove from
# the final image after compiling Python
PYTHON_COMPILE_DEPS="zlib-devel bzip2-devel ncurses-devel sqlite-devel readline-devel tk-devel gdbm-devel db4-devel libpcap-devel xz-devel"

# Libraries that are allowed as part of the manylinux2010 profile
MANYLINUX2010_DEPS="glibc-devel libstdc++-devel glib2-devel libX11-devel libXext-devel libXrender-devel mesa-libGL-devel libICE-devel libSM-devel"

# Get build utilities
source $MY_DIR/build_utils.sh

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

# EPEL support
yum -y install wget
# https://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
cp $MY_DIR/epel-release-6-8.noarch.rpm .
check_sha256sum epel-release-6-8.noarch.rpm $EPEL_RPM_HASH

# Dev toolset (for LLVM and other projects requiring C++11 support)
wget -q http://people.centos.org/tru/devtools-2/devtools-2.repo
check_sha256sum devtools-2.repo $DEVTOOLS_HASH
mv devtools-2.repo /etc/yum.repos.d/devtools-2.repo
rpm -Uvh --replacepkgs epel-release-6*.rpm
rm -f epel-release-6*.rpm

# Development tools and libraries
yum -y install bzip2 make patch unzip bison yasm diffutils \
    automake which file cmake28 \
    kernel-devel-`uname -r` \
    expat-devel gettext \
    perl-devel \
    devtoolset-2-binutils devtoolset-2-gcc \
    devtoolset-2-gcc-c++ devtoolset-2-gcc-gfortran \
    ${PYTHON_COMPILE_DEPS}

# Build an OpenSSL for both curl and the Pythons. We'll delete this at the end.
build_openssl $OPENSSL_ROOT $OPENSSL_HASH
# Install curl so we can have TLS 1.2 in this ancient container.
build_curl $CURL_ROOT $CURL_HASH
hash -r
curl --version
curl-config --features

# Install a git we link against OpenSSL so that we can use TLS 1.2
build_git $GIT_ROOT $GIT_HASH
git version

# Install newest autoconf
build_autoconf $AUTOCONF_ROOT $AUTOCONF_HASH
autoconf --version

# Install newest automake
build_automake $AUTOMAKE_ROOT $AUTOMAKE_HASH
automake --version

# Install newest libtool
build_libtool $LIBTOOL_ROOT $LIBTOOL_HASH
libtool --version

# Install a more recent SQLite3
curl -fsSLO https://sqlite.org/2017/$SQLITE_AUTOCONF_VERSION.tar.gz
check_sha256sum $SQLITE_AUTOCONF_VERSION.tar.gz $SQLITE_AUTOCONF_HASH
tar xfz $SQLITE_AUTOCONF_VERSION.tar.gz
cd $SQLITE_AUTOCONF_VERSION
./configure
make install
cd ..
rm -rf $SQLITE_AUTOCONF_VERSION*

# Compile the latest Python releases.
# (In order to have a proper SSL module, Python is compiled
# against a recent openssl [see env vars above], which is linked
# statically.
mkdir -p /opt/python
build_cpythons $CPYTHON_VERSIONS

PY36_BIN=/opt/python/cp36-cp36m/bin

# Install certifi and auditwheel
$PY36_BIN/pip install --require-hashes -r $MY_DIR/py36-requirements.txt

# Our openssl doesn't know how to find the system CA trust store
#   (https://github.com/pypa/manylinux/issues/53)
# And it's not clear how up-to-date that is anyway
# So let's just use the same one pip and everyone uses
ln -s $($PY36_BIN/python -c 'import certifi; print(certifi.where())') \
      /opt/_internal/certs.pem
# If you modify this line you also have to modify the versions in the
# Dockerfiles:
export SSL_CERT_FILE=/opt/_internal/certs.pem

# Now we can delete our built OpenSSL headers/static libs since we've linked everything we need
rm -rf /usr/local/ssl

# Install patchelf (latest with unreleased bug fixes)
curl -fsSL -o patchelf.tar.gz https://github.com/NixOS/patchelf/archive/$PATCHELF_VERSION.tar.gz
check_sha256sum patchelf.tar.gz $PATCHELF_HASH
tar -xzf patchelf.tar.gz
(cd patchelf-$PATCHELF_VERSION && ./bootstrap.sh && ./configure && make && make install)
rm -rf patchelf.tar.gz patchelf-$PATCHELF_VERSION

ln -s $PY36_BIN/auditwheel /usr/local/bin/auditwheel

# HACK: The newly compiled and installed curl messes with the system's
# py2.6 installation, on which yum depends.  Work around it by
# rewiring libcurl.so specifically for yum.  /usr/local/bin/ has higher
# priority on the PATH than /usr/bin/
cat <<'EOF' > /usr/local/bin/yum && chmod +x /usr/local/bin/yum
#!/bin/bash
if [ "x$(arch)" != xi686 ]; then
  LD_PRELOAD=/usr/lib64/libcurl.so.4
else
  LD_PRELOAD=/usr/lib/libcurl.so.4 
fi
export LD_PRELOAD
/usr/bin/yum "$@"
EOF
# the above might not shadow the real yum just yet, so call hash to be
# sure:
type yum
hash yum

# Clean up development headers and other unnecessary stuff for
# final image
yum -y erase wireless-tools gtk2 libX11 hicolor-icon-theme \
    avahi freetype bitstream-vera-fonts \
    expat-devel gettext \
    ${PYTHON_COMPILE_DEPS}
yum -y install ${MANYLINUX2010_DEPS}
yum -y clean all
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
    $PYTHON $MY_DIR/manylinux-check.py
    # Make sure that SSL cert checking works
    $PYTHON $MY_DIR/ssl-check.py
done

# Fix libc headers to remain compatible with C99 compilers.
find /usr/include/ -type f -exec sed -i 's/\bextern _*inline_*\b/extern __inline __attribute__ ((__gnu_inline__))/g' {} +

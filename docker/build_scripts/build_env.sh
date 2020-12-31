# source me

PYTHON_DOWNLOAD_URL=https://www.python.org/ftp/python
# of the form <maj>.<min>.<rev> or <maj>.<min>.<rev>rc<n>
CPYTHON_VERSIONS="2.7.18 3.5.10 3.6.12 3.7.9 3.8.7 3.9.1"

# perl is needed to build openssl
PERL_ROOT=perl-5.30.2
PERL_HASH=66db7df8a91979eb576fac91743644da878244cf8ee152f02cd6f5cd7a731689
PERL_DOWNLOAD_URL=https://www.cpan.org/src/5.0

# openssl version to build, with expected sha256 hash of .tar.gz
# archive.
OPENSSL_ROOT=openssl-1.1.1i
OPENSSL_HASH=e8be6a35fe41d10603c3cc635e93289ed00bf34b79671a3a4de64fcee00d5242
OPENSSL_DOWNLOAD_URL=https://www.openssl.org/source

PATCHELF_VERSION=0.12
PATCHELF_HASH=3dca33fb862213b3541350e1da262249959595903f559eae0fbc68966e9c3f56
PATCHELF_DOWNLOAD_URL=https://github.com/NixOS/patchelf/archive

CURL_ROOT=curl-7.72.0
CURL_HASH=d4d5899a3868fbb6ae1856c3e55a32ce35913de3956d1973caccd37bd0174fa2
CURL_DOWNLOAD_URL=https://curl.haxx.se/download

AUTOCONF_ROOT=autoconf-2.70
AUTOCONF_HASH=f05f410fda74323ada4bdc4610db37f8dbd556602ba65bc843edb4d4d4a1b2b7
AUTOCONF_DOWNLOAD_URL=http://ftp.gnu.org/gnu/autoconf
AUTOMAKE_ROOT=automake-1.16.2
AUTOMAKE_HASH=b2f361094b410b4acbf4efba7337bdb786335ca09eb2518635a09fb7319ca5c1
AUTOMAKE_DOWNLOAD_URL=http://ftp.gnu.org/gnu/automake
LIBTOOL_ROOT=libtool-2.4.6
LIBTOOL_HASH=e3bd4d5d3d025a36c21dd6af7ea818a2afcd4dfc1ea5a17b39d7854bcd0c06e3
LIBTOOL_DOWNLOAD_URL=http://ftp.gnu.org/gnu/libtool

SQLITE_AUTOCONF_ROOT=sqlite-autoconf-3330000
SQLITE_AUTOCONF_HASH=106a2c48c7f75a298a7557bcc0d5f4f454e5b43811cc738b7ca294d6956bbb15
SQLITE_AUTOCONF_DOWNLOAD_URL=https://www.sqlite.org/2020

LIBXCRYPT_VERSION=4.4.17
LIBXCRYPT_HASH=7665168d0409574a03f7b484682e68334764c29c21ca5df438955a381384ca07
LIBXCRYPT_DOWNLOAD_URL=https://github.com/besser82/libxcrypt/archive

GIT_ROOT=git-2.29.1
GIT_HASH=728845a66103d8d1572a656123c2c09d7aa4c0ab8f4c3dc3911e14e18c85ee67
GIT_DOWNLOAD_URL=https://www.kernel.org/pub/software/scm/git

EPEL_RPM_HASH=0dcc89f9bf67a2a515bad64569b7a9615edc5e018f676a578d5fd0f17d3c81d4
DEVTOOLS_HASH=a8ebeb4bed624700f727179e6ef771dafe47651131a00a78b342251415646acc

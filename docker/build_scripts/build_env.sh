# source me

PYTHON_DOWNLOAD_URL=https://www.python.org/ftp/python
# of the form <maj>.<min>.<rev> or <maj>.<min>.<rev>rc<n>
CPYTHON_VERSIONS="2.7.18 3.5.10 3.6.15 3.7.12 3.8.12 3.9.9"

# perl is needed to build openssl and libxcrypt
PERL_ROOT=perl-5.34.0
PERL_HASH=551efc818b968b05216024fb0b727ef2ad4c100f8cb6b43fab615fa78ae5be9a
PERL_DOWNLOAD_URL=https://www.cpan.org/src/5.0

# openssl version to build, with expected sha256 hash of .tar.gz
# archive.
OPENSSL_ROOT=openssl-1.1.1m
OPENSSL_HASH=f89199be8b23ca45fc7cb9f1d8d3ee67312318286ad030f5316aca6462db6c96
OPENSSL_DOWNLOAD_URL=https://www.openssl.org/source

PATCHELF_VERSION=0.13.1
PATCHELF_HASH=f6d5ecdb51ad78e963233cfde15020f9eebc9d9c7c747aaed54ce39c284ad019
PATCHELF_DOWNLOAD_URL=https://github.com/NixOS/patchelf/archive

CURL_ROOT=curl-7.80.0
CURL_HASH=dab997c9b08cb4a636a03f2f7f985eaba33279c1c52692430018fae4a4878dc7
CURL_DOWNLOAD_URL=https://curl.haxx.se/download

AUTOCONF_ROOT=autoconf-2.71
AUTOCONF_HASH=431075ad0bf529ef13cb41e9042c542381103e80015686222b8a9d4abef42a1c
AUTOCONF_DOWNLOAD_URL=http://ftp.gnu.org/gnu/autoconf
AUTOMAKE_ROOT=automake-1.16.5
AUTOMAKE_HASH=07bd24ad08a64bc17250ce09ec56e921d6343903943e99ccf63bbf0705e34605
AUTOMAKE_DOWNLOAD_URL=http://ftp.gnu.org/gnu/automake
LIBTOOL_ROOT=libtool-2.4.6
LIBTOOL_HASH=e3bd4d5d3d025a36c21dd6af7ea818a2afcd4dfc1ea5a17b39d7854bcd0c06e3
LIBTOOL_DOWNLOAD_URL=http://ftp.gnu.org/gnu/libtool

SQLITE_AUTOCONF_ROOT=sqlite-autoconf-3370000
SQLITE_AUTOCONF_HASH=731a4651d4d4b36fc7d21db586b2de4dd00af31fd54fb5a9a4b7f492057479f7
SQLITE_AUTOCONF_DOWNLOAD_URL=https://www.sqlite.org/2021

LIBXCRYPT_VERSION=4.4.26
LIBXCRYPT_HASH=e8a544dd19171c1e6191a6044c96cc31496d781ba08b5a00f53310d001d58114
LIBXCRYPT_DOWNLOAD_URL=https://github.com/besser82/libxcrypt/archive

GIT_ROOT=git-2.34.1
GIT_HASH=fc4eb5ecb9299db91cdd156c06cdeb41833f53adc5631ddf8c0cb13eaa2911c1
GIT_DOWNLOAD_URL=https://www.kernel.org/pub/software/scm/git

CACERT_ROOT=cacert
CACERT_EXTENSION=.pem
CACERT_DOWNLOAD_URL=https://raw.githubusercontent.com/certifi/python-certifi/2021.05.30/certifi
CACERT_HASH=de2fa17c4d8ae68dc204a1b6b58b7a7a12569367cfeb8a3a4e1f377c73e83e9e

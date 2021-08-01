# source me

PYTHON_DOWNLOAD_URL=https://www.python.org/ftp/python
# of the form <maj>.<min>.<rev> or <maj>.<min>.<rev>rc<n>
CPYTHON_VERSIONS="2.7.18 3.5.10 3.6.14 3.7.11 3.8.11 3.9.6"

# perl is needed to build openssl
PERL_ROOT=perl-5.32.1
PERL_HASH=03b693901cd8ae807231b1787798cf1f2e0b8a56218d07b7da44f784a7caeb2c
PERL_DOWNLOAD_URL=https://www.cpan.org/src/5.0

# openssl version to build, with expected sha256 hash of .tar.gz
# archive.
OPENSSL_ROOT=openssl-1.1.1k
OPENSSL_HASH=892a0875b9872acd04a9fde79b1f943075d5ea162415de3047c327df33fbaee5
OPENSSL_DOWNLOAD_URL=https://www.openssl.org/source

PATCHELF_VERSION=0.12
PATCHELF_HASH=3dca33fb862213b3541350e1da262249959595903f559eae0fbc68966e9c3f56
PATCHELF_DOWNLOAD_URL=https://github.com/NixOS/patchelf/archive

CURL_ROOT=curl-7.77.0
CURL_HASH=b0a3428acb60fa59044c4d0baae4e4fc09ae9af1d8a3aa84b2e3fbcd99841f77
CURL_DOWNLOAD_URL=https://curl.haxx.se/download

AUTOCONF_ROOT=autoconf-2.71
AUTOCONF_HASH=431075ad0bf529ef13cb41e9042c542381103e80015686222b8a9d4abef42a1c
AUTOCONF_DOWNLOAD_URL=http://ftp.gnu.org/gnu/autoconf
AUTOMAKE_ROOT=automake-1.16.4
AUTOMAKE_HASH=8a0f0be7aaae2efa3a68482af28e5872d8830b9813a6a932a2571eac63ca1794
AUTOMAKE_DOWNLOAD_URL=http://ftp.gnu.org/gnu/automake
LIBTOOL_ROOT=libtool-2.4.6
LIBTOOL_HASH=e3bd4d5d3d025a36c21dd6af7ea818a2afcd4dfc1ea5a17b39d7854bcd0c06e3
LIBTOOL_DOWNLOAD_URL=http://ftp.gnu.org/gnu/libtool

SQLITE_AUTOCONF_ROOT=sqlite-autoconf-3360000
SQLITE_AUTOCONF_HASH=bd90c3eb96bee996206b83be7065c9ce19aef38c3f4fb53073ada0d0b69bbce3
SQLITE_AUTOCONF_DOWNLOAD_URL=https://www.sqlite.org/2021

LIBXCRYPT_VERSION=4.4.17
LIBXCRYPT_HASH=7665168d0409574a03f7b484682e68334764c29c21ca5df438955a381384ca07
LIBXCRYPT_DOWNLOAD_URL=https://github.com/besser82/libxcrypt/archive

GIT_ROOT=git-2.32.0
GIT_HASH=6038f06d396ba9dab2eee541c7db6e7f9f847f181ec62f3d8441893f8c469398
GIT_DOWNLOAD_URL=https://www.kernel.org/pub/software/scm/git

EPEL_RPM_HASH=0dcc89f9bf67a2a515bad64569b7a9615edc5e018f676a578d5fd0f17d3c81d4
DEVTOOLS_HASH=a8ebeb4bed624700f727179e6ef771dafe47651131a00a78b342251415646acc

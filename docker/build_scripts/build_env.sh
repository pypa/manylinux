# source me

PYTHON_DOWNLOAD_URL=https://www.python.org/ftp/python
# of the form <maj>.<min>.<rev> or <maj>.<min>.<rev>rc<n>
CPYTHON_VERSIONS="2.7.18 3.5.10 3.6.15 3.7.13 3.8.13 3.9.12"

# perl is needed to build openssl and libxcrypt
PERL_ROOT=perl-5.34.0
PERL_HASH=551efc818b968b05216024fb0b727ef2ad4c100f8cb6b43fab615fa78ae5be9a
PERL_DOWNLOAD_URL=https://www.cpan.org/src/5.0

# openssl version to build, with expected sha256 hash of .tar.gz
# archive.
OPENSSL_ROOT=openssl-1.1.1n
OPENSSL_HASH=40dceb51a4f6a5275bde0e6bf20ef4b91bfc32ed57c0552e2e8e15463372b17a
OPENSSL_DOWNLOAD_URL=https://www.openssl.org/source

CURL_ROOT=curl-7.83.0
CURL_HASH=c0e64302a33d2fb79e0fc4e674260a22941e92ee2f11b894bf94d32b8f5531af
CURL_DOWNLOAD_URL=https://curl.haxx.se/download

AUTOCONF_ROOT=autoconf-2.71
AUTOCONF_HASH=431075ad0bf529ef13cb41e9042c542381103e80015686222b8a9d4abef42a1c
AUTOCONF_DOWNLOAD_URL=http://ftp.gnu.org/gnu/autoconf
AUTOMAKE_ROOT=automake-1.16.5
AUTOMAKE_HASH=07bd24ad08a64bc17250ce09ec56e921d6343903943e99ccf63bbf0705e34605
AUTOMAKE_DOWNLOAD_URL=http://ftp.gnu.org/gnu/automake
LIBTOOL_ROOT=libtool-2.4.7
LIBTOOL_HASH=04e96c2404ea70c590c546eba4202a4e12722c640016c12b9b2f1ce3d481e9a8
LIBTOOL_DOWNLOAD_URL=http://ftp.gnu.org/gnu/libtool

SQLITE_AUTOCONF_ROOT=sqlite-autoconf-3380500
SQLITE_AUTOCONF_HASH=5af07de982ba658fd91a03170c945f99c971f6955bc79df3266544373e39869c
SQLITE_AUTOCONF_DOWNLOAD_URL=https://www.sqlite.org/2022

LIBXCRYPT_VERSION=4.4.28
LIBXCRYPT_HASH=db7e37901969cb1d1e8020cb73a991ef81e48e31ea5b76a101862c806426b457
LIBXCRYPT_DOWNLOAD_URL=https://github.com/besser82/libxcrypt/archive

GIT_ROOT=git-2.35.3
GIT_HASH=cad708072d5c0b390c71651f5edb44143f00b357766973470bf9adebc0944c03
GIT_DOWNLOAD_URL=https://www.kernel.org/pub/software/scm/git

CACERT_ROOT=cacert
CACERT_EXTENSION=.pem
CACERT_DOWNLOAD_URL=https://raw.githubusercontent.com/certifi/python-certifi/2021.05.30/certifi
CACERT_HASH=de2fa17c4d8ae68dc204a1b6b58b7a7a12569367cfeb8a3a4e1f377c73e83e9e

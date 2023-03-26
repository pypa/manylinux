# source me

PYTHON_DOWNLOAD_URL=https://www.python.org/ftp/python
# of the form <maj>.<min>.<rev> or <maj>.<min>.<rev>rc<n>
CPYTHON_VERSIONS="2.7.18 3.5.10 3.6.15 3.7.16 3.8.16 3.9.16"

# perl is needed to build openssl and libxcrypt
PERL_ROOT=perl-5.34.0
PERL_HASH=551efc818b968b05216024fb0b727ef2ad4c100f8cb6b43fab615fa78ae5be9a
PERL_DOWNLOAD_URL=https://www.cpan.org/src/5.0

# openssl version to build, with expected sha256 hash of .tar.gz
# archive.
OPENSSL_ROOT=openssl-1.1.1t
OPENSSL_HASH=8dee9b24bdb1dcbf0c3d1e9b02fb8f6bf22165e807f45adeb7c9677536859d3b
OPENSSL_DOWNLOAD_URL=https://www.openssl.org/source

CURL_ROOT=curl-8.0.0
CURL_HASH=8d437cd8cd70609c70eea0b1cbeb8755145140d1ffe175108e3cebe8619501a6
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

SQLITE_AUTOCONF_ROOT=sqlite-autoconf-3410200
SQLITE_AUTOCONF_HASH=e98c100dd1da4e30fa460761dab7c0b91a50b785e167f8c57acc46514fae9499
SQLITE_AUTOCONF_DOWNLOAD_URL=https://www.sqlite.org/2023

LIBXCRYPT_VERSION=4.4.33
LIBXCRYPT_HASH=0a0c06bcd028fd0f0467f89f6a451112e8ec97c36e0f58e7464449a4c04607ed
LIBXCRYPT_DOWNLOAD_URL=https://github.com/besser82/libxcrypt/archive

GIT_ROOT=git-2.35.7
GIT_HASH=fc849272a95cc7457091221a645fcd753b3b1984767ee3323fb6a0aa944bbcb4
GIT_DOWNLOAD_URL=https://www.kernel.org/pub/software/scm/git

CACERT_ROOT=cacert
CACERT_EXTENSION=.pem
CACERT_DOWNLOAD_URL=https://raw.githubusercontent.com/certifi/python-certifi/2021.05.30/certifi
CACERT_HASH=de2fa17c4d8ae68dc204a1b6b58b7a7a12569367cfeb8a3a4e1f377c73e83e9e

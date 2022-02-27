# default to latest supported policy, x86_64
ARG BASEIMAGE=amd64/debian:9
ARG POLICY=manylinux_2_24
ARG PLATFORM=x86_64
ARG DEVTOOLSET_ROOTPATH=
ARG LD_LIBRARY_PATH_ARG=
ARG PREPEND_PATH=

FROM $BASEIMAGE AS runtime_base
ARG POLICY
ARG PLATFORM
ARG DEVTOOLSET_ROOTPATH
ARG LD_LIBRARY_PATH_ARG
ARG PREPEND_PATH
LABEL maintainer="The ManyLinux project"

ENV AUDITWHEEL_POLICY=${POLICY} AUDITWHEEL_ARCH=${PLATFORM} AUDITWHEEL_PLAT=${POLICY}_${PLATFORM}
ENV LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8
ENV DEVTOOLSET_ROOTPATH=${DEVTOOLSET_ROOTPATH}
ENV LD_LIBRARY_PATH=${LD_LIBRARY_PATH_ARG}
ENV PATH=${PREPEND_PATH}${PATH}
ENV PKG_CONFIG_PATH=/usr/local/lib/pkgconfig

# first copy the fixup mirrors script, keep the script around
COPY build_scripts/fixup-mirrors.sh /usr/local/sbin/fixup-mirrors

# setup entrypoint, this will wrap commands with `linux32` with i686 images
COPY build_scripts/install-entrypoint.sh \
     build_scripts/update-system-packages.sh \
     build_scripts/build_utils.sh \
     /build_scripts/

RUN /build_scripts/install-entrypoint.sh && rm -rf /build_scripts
COPY manylinux-entrypoint /usr/local/bin/manylinux-entrypoint
ENTRYPOINT ["manylinux-entrypoint"]

COPY build_scripts/install-runtime-packages.sh \
     build_scripts/update-system-packages.sh \
     build_scripts/build_utils.sh \
     /build_scripts/
RUN manylinux-entrypoint /build_scripts/install-runtime-packages.sh && rm -rf /build_scripts/

COPY build_scripts/build_utils.sh /build_scripts/

COPY build_scripts/install-autoconf.sh /build_scripts/
RUN export AUTOCONF_ROOT=autoconf-2.71 && \
    export AUTOCONF_HASH=431075ad0bf529ef13cb41e9042c542381103e80015686222b8a9d4abef42a1c && \
    export AUTOCONF_DOWNLOAD_URL=http://ftp.gnu.org/gnu/autoconf && \
    manylinux-entrypoint /build_scripts/install-autoconf.sh

COPY build_scripts/install-automake.sh /build_scripts/
RUN export AUTOMAKE_ROOT=automake-1.16.5 && \
    export AUTOMAKE_HASH=07bd24ad08a64bc17250ce09ec56e921d6343903943e99ccf63bbf0705e34605 && \
    export AUTOMAKE_DOWNLOAD_URL=http://ftp.gnu.org/gnu/automake && \
    manylinux-entrypoint /build_scripts/install-automake.sh

COPY build_scripts/install-libtool.sh /build_scripts/
RUN export LIBTOOL_ROOT=libtool-2.4.6 && \
    export LIBTOOL_HASH=e3bd4d5d3d025a36c21dd6af7ea818a2afcd4dfc1ea5a17b39d7854bcd0c06e3 && \
    export LIBTOOL_DOWNLOAD_URL=http://ftp.gnu.org/gnu/libtool && \
    manylinux-entrypoint /build_scripts/install-libtool.sh

COPY build_scripts/install-libxcrypt.sh /build_scripts/
RUN export LIBXCRYPT_VERSION=4.4.28 && \
    export LIBXCRYPT_HASH=db7e37901969cb1d1e8020cb73a991ef81e48e31ea5b76a101862c806426b457 && \
    export LIBXCRYPT_DOWNLOAD_URL=https://github.com/besser82/libxcrypt/archive && \
    export PERL_ROOT=perl-5.34.0 && \
    export PERL_HASH=551efc818b968b05216024fb0b727ef2ad4c100f8cb6b43fab615fa78ae5be9a && \
    export PERL_DOWNLOAD_URL=https://www.cpan.org/src/5.0 && \
    manylinux-entrypoint /build_scripts/install-libxcrypt.sh

FROM runtime_base AS build_base
COPY build_scripts/install-build-packages.sh /build_scripts/
RUN manylinux-entrypoint /build_scripts/install-build-packages.sh


FROM build_base AS build_git
COPY build_scripts/build-git.sh /build_scripts/
RUN export GIT_ROOT=git-2.35.1 && \
    export GIT_HASH=9845a37dd01f9faaa7d8aa2078399d3aea91b43819a5efea6e2877b0af09bd43 && \
    export GIT_DOWNLOAD_URL=https://www.kernel.org/pub/software/scm/git && \
    manylinux-entrypoint /build_scripts/build-git.sh


FROM build_base AS build_swig
COPY build_scripts/build-swig.sh /build_scripts/
RUN export SWIG_ROOT=swig-4.0.2 && \
    export SWIG_HASH=d53be9730d8d58a16bf0cbd1f8ac0c0c3e1090573168bfa151b01eb47fa906fc && \
    export SWIG_DOWNLOAD_URL=https://sourceforge.net/projects/swig/files/swig/${SWIG_ROOT} && \
    export PCRE_ROOT=pcre-8.45 && \
    export PCRE_HASH=4e6ce03e0336e8b4a3d6c2b70b1c5e18590a5673a98186da90d4f33c23defc09 && \
    export PCRE_DOWNLOAD_URL=https://sourceforge.net/projects/pcre/files/pcre/8.45 && \
    manylinux-entrypoint /build_scripts/build-swig.sh


FROM build_base AS build_cpython
COPY build_scripts/build-sqlite3.sh /build_scripts/
RUN export SQLITE_AUTOCONF_ROOT=sqlite-autoconf-3380000 && \
    export SQLITE_AUTOCONF_HASH=1c76e25dc63d9f3935e0f406aec520a33ee77cf54ea5147dffe1fae8369eff68 && \
    export SQLITE_AUTOCONF_DOWNLOAD_URL=https://www.sqlite.org/2022 && \
    manylinux-entrypoint /build_scripts/build-sqlite3.sh

COPY build_scripts/build-openssl.sh /build_scripts/
RUN export OPENSSL_ROOT=openssl-1.1.1m && \
    export OPENSSL_HASH=f89199be8b23ca45fc7cb9f1d8d3ee67312318286ad030f5316aca6462db6c96 && \
    export OPENSSL_DOWNLOAD_URL=https://www.openssl.org/source && \
    manylinux-entrypoint /build_scripts/build-openssl.sh

COPY build_scripts/build-cpython.sh /build_scripts/


FROM build_cpython AS build_cpython36
COPY build_scripts/cpython-pubkeys.txt /build_scripts/cpython-pubkeys.txt
RUN manylinux-entrypoint /build_scripts/build-cpython.sh 3.6.15


FROM build_cpython AS build_cpython37
COPY build_scripts/cpython-pubkeys.txt /build_scripts/cpython-pubkeys.txt
RUN manylinux-entrypoint /build_scripts/build-cpython.sh 3.7.12


FROM build_cpython AS build_cpython38
COPY build_scripts/ambv-pubkey.txt /build_scripts/cpython-pubkeys.txt
RUN manylinux-entrypoint /build_scripts/build-cpython.sh 3.8.12


FROM build_cpython AS build_cpython39
COPY build_scripts/ambv-pubkey.txt /build_scripts/cpython-pubkeys.txt
RUN manylinux-entrypoint /build_scripts/build-cpython.sh 3.9.10


FROM build_cpython AS build_cpython310
COPY build_scripts/cpython-pubkey-310-311.txt /build_scripts/cpython-pubkeys.txt
RUN manylinux-entrypoint /build_scripts/build-cpython.sh 3.10.2


FROM build_cpython AS all_python
COPY build_scripts/install-pypy.sh \
     build_scripts/pypy.sha256 \
     build_scripts/finalize-python.sh \
     /build_scripts/
# PyPy 3.7 v7.3.8 is broken, see https://foss.heptapod.net/pypy/pypy/-/issues/3688
RUN manylinux-entrypoint /build_scripts/install-pypy.sh 3.7 7.3.7
RUN manylinux-entrypoint /build_scripts/install-pypy.sh 3.8 7.3.8
RUN manylinux-entrypoint /build_scripts/install-pypy.sh 3.9 7.3.8
COPY --from=build_cpython36 /opt/_internal /opt/_internal/
COPY --from=build_cpython37 /opt/_internal /opt/_internal/
COPY --from=build_cpython38 /opt/_internal /opt/_internal/
COPY --from=build_cpython39 /opt/_internal /opt/_internal/
COPY --from=build_cpython310 /opt/_internal /opt/_internal/
RUN manylinux-entrypoint /build_scripts/finalize-python.sh


FROM runtime_base
COPY --from=build_git /manylinux-rootfs /
COPY --from=build_swig /manylinux-rootfs /
COPY --from=build_cpython /manylinux-rootfs /
COPY --from=all_python /opt/_internal /opt/_internal/
COPY build_scripts/finalize.sh \
     build_scripts/update-system-packages.sh \
     build_scripts/python-tag-abi-tag.py \
     build_scripts/requirements3.6.txt \
     build_scripts/requirements3.7.txt \
     build_scripts/requirements3.8.txt \
     build_scripts/requirements3.9.txt \
     build_scripts/requirements3.10.txt \
     build_scripts/requirements-base-tools.txt \
     /build_scripts/
COPY build_scripts/requirements-tools/* /build_scripts/requirements-tools/
RUN manylinux-entrypoint /build_scripts/finalize.sh && rm -rf /build_scripts

ENV SSL_CERT_FILE=/opt/_internal/certs.pem

CMD ["/bin/bash"]

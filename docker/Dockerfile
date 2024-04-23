# default to latest supported policy, x86_64
ARG BASEIMAGE=amd64/almalinux:8
ARG POLICY=manylinux_2_28
ARG PLATFORM=x86_64
ARG DEVTOOLSET_ROOTPATH=/opt/rh/gcc-toolset-12/root
ARG LD_LIBRARY_PATH_ARG=${DEVTOOLSET_ROOTPATH}/usr/lib64:${DEVTOOLSET_ROOTPATH}/usr/lib:${DEVTOOLSET_ROOTPATH}/usr/lib64/dyninst:${DEVTOOLSET_ROOTPATH}/usr/lib/dyninst
ARG PREPEND_PATH=${DEVTOOLSET_ROOTPATH}/usr/bin:

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
RUN export AUTOCONF_ROOT=autoconf-2.72 && \
    export AUTOCONF_HASH=afb181a76e1ee72832f6581c0eddf8df032b83e2e0239ef79ebedc4467d92d6e && \
    export AUTOCONF_DOWNLOAD_URL=http://ftp.gnu.org/gnu/autoconf && \
    manylinux-entrypoint /build_scripts/install-autoconf.sh

COPY build_scripts/install-automake.sh /build_scripts/
RUN export AUTOMAKE_ROOT=automake-1.16.5 && \
    export AUTOMAKE_HASH=07bd24ad08a64bc17250ce09ec56e921d6343903943e99ccf63bbf0705e34605 && \
    export AUTOMAKE_DOWNLOAD_URL=http://ftp.gnu.org/gnu/automake && \
    manylinux-entrypoint /build_scripts/install-automake.sh

COPY build_scripts/install-libtool.sh /build_scripts/
RUN export LIBTOOL_ROOT=libtool-2.4.7 && \
    export LIBTOOL_HASH=04e96c2404ea70c590c546eba4202a4e12722c640016c12b9b2f1ce3d481e9a8 && \
    export LIBTOOL_DOWNLOAD_URL=http://ftp.gnu.org/gnu/libtool && \
    manylinux-entrypoint /build_scripts/install-libtool.sh

COPY build_scripts/install-libxcrypt.sh /build_scripts/
RUN export LIBXCRYPT_VERSION=4.4.36 && \
    export LIBXCRYPT_HASH=b979838d5f1f238869d467484793b72b8bca64c4eae696fdbba0a9e0b6c28453 && \
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
RUN export GIT_ROOT=git-2.44.0 && \
    export GIT_HASH=f9e36f085458fe9688fbbe7846b8c4770b13d161fcd8953655f36b2b85f06b76 && \
    export GIT_DOWNLOAD_URL=https://www.kernel.org/pub/software/scm/git && \
    manylinux-entrypoint /build_scripts/build-git.sh


FROM build_base AS build_cpython_system_ssl
COPY build_scripts/build-sqlite3.sh /build_scripts/
RUN export SQLITE_AUTOCONF_ROOT=sqlite-autoconf-3450300 && \
    export SQLITE_AUTOCONF_HASH=b2809ca53124c19c60f42bf627736eae011afdcc205bb48270a5ee9a38191531 && \
    export SQLITE_AUTOCONF_DOWNLOAD_URL=https://www.sqlite.org/2024 && \
    manylinux-entrypoint /build_scripts/build-sqlite3.sh

COPY build_scripts/build-tcltk.sh /build_scripts/
RUN export TCL_ROOT=tcl8.6.14 && \
    export TCL_HASH=5880225babf7954c58d4fb0f5cf6279104ce1cd6aa9b71e9a6322540e1c4de66 && \
    export TCL_DOWNLOAD_URL=https://prdownloads.sourceforge.net/tcl && \
    export TK_ROOT=tk8.6.14 && \
    export TK_HASH=8ffdb720f47a6ca6107eac2dd877e30b0ef7fac14f3a84ebbd0b3612cee41a94 && \
    manylinux-entrypoint /build_scripts/build-tcltk.sh

COPY build_scripts/build-cpython.sh /build_scripts/


FROM build_cpython_system_ssl AS build_cpython
COPY build_scripts/build-openssl.sh /build_scripts/
RUN export OPENSSL_ROOT=openssl-3.0.13 && \
    export OPENSSL_HASH=88525753f79d3bec27d2fa7c66aa0b92b3aa9498dafd93d7cfa4b3780cdae313 && \
    export OPENSSL_DOWNLOAD_URL=https://www.openssl.org/source && \
    manylinux-entrypoint /build_scripts/build-openssl.sh


FROM build_cpython_system_ssl AS build_cpython36
COPY build_scripts/cpython-pubkeys.txt /build_scripts/cpython-pubkeys.txt
RUN manylinux-entrypoint /build_scripts/build-cpython.sh 3.6.15


FROM build_cpython_system_ssl AS build_cpython37
COPY build_scripts/cpython-pubkeys.txt /build_scripts/cpython-pubkeys.txt
RUN manylinux-entrypoint /build_scripts/build-cpython.sh 3.7.17


FROM build_cpython AS build_cpython38
COPY build_scripts/ambv-pubkey.txt /build_scripts/cpython-pubkeys.txt
RUN manylinux-entrypoint /build_scripts/build-cpython.sh 3.8.19


FROM build_cpython AS build_cpython39
COPY build_scripts/ambv-pubkey.txt /build_scripts/cpython-pubkeys.txt
RUN manylinux-entrypoint /build_scripts/build-cpython.sh 3.9.19


FROM build_cpython AS build_cpython310
COPY build_scripts/cpython-pubkey-310-311.txt /build_scripts/cpython-pubkeys.txt
RUN manylinux-entrypoint /build_scripts/build-cpython.sh 3.10.14

FROM build_cpython AS build_cpython311
COPY build_scripts/cpython-pubkey-310-311.txt /build_scripts/cpython-pubkeys.txt
RUN manylinux-entrypoint /build_scripts/build-cpython.sh 3.11.9

FROM build_cpython AS build_cpython312
COPY build_scripts/cpython-pubkey-312-313.txt /build_scripts/cpython-pubkeys.txt
RUN manylinux-entrypoint /build_scripts/build-cpython.sh 3.12.3

FROM build_cpython AS all_cpython
COPY build_scripts/finalize-python.sh /build_scripts/
RUN --mount=type=bind,target=/build_cpython36,from=build_cpython36 \
    --mount=type=bind,target=/build_cpython37,from=build_cpython37 \
    --mount=type=bind,target=/build_cpython38,from=build_cpython38 \
    --mount=type=bind,target=/build_cpython39,from=build_cpython39 \
    --mount=type=bind,target=/build_cpython310,from=build_cpython310 \
    --mount=type=bind,target=/build_cpython311,from=build_cpython311 \
    --mount=type=bind,target=/build_cpython312,from=build_cpython312 \
    mkdir -p /opt/_internal && \
    cp -rf /build_cpython*/opt/_internal/* /opt/_internal/ && \
    manylinux-entrypoint /build_scripts/finalize-python.sh


FROM runtime_base
COPY --from=build_git /manylinux-rootfs /
COPY --from=build_cpython /manylinux-rootfs /
COPY build_scripts /opt/_internal/build_scripts/
RUN --mount=type=bind,target=/all_cpython,from=all_cpython \
    cp -rf /all_cpython/opt/_internal/* /opt/_internal/ && \
    manylinux-entrypoint /opt/_internal/build_scripts/finalize.sh \
    pp37-pypy37_pp73 \
    pp38-pypy38_pp73 \
    pp39-pypy39_pp73 \
    pp310-pypy310_pp73

ENV SSL_CERT_FILE=/opt/_internal/certs.pem

CMD ["/bin/bash"]

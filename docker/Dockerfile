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
RUN export AUTOMAKE_ROOT=automake-1.17 && \
    export AUTOMAKE_HASH=397767d4db3018dd4440825b60c64258b636eaf6bf99ac8b0897f06c89310acd && \
    export AUTOMAKE_DOWNLOAD_URL=http://ftp.gnu.org/gnu/automake && \
    manylinux-entrypoint /build_scripts/install-automake.sh

COPY build_scripts/install-libtool.sh /build_scripts/
RUN export LIBTOOL_ROOT=libtool-2.5.3 && \
    export LIBTOOL_HASH=9322bd8f6bc848fda3e385899dd1934957169652acef716d19d19d24053abb95 && \
    export LIBTOOL_DOWNLOAD_URL=http://ftp.gnu.org/gnu/libtool && \
    manylinux-entrypoint /build_scripts/install-libtool.sh

COPY build_scripts/install-libxcrypt.sh /build_scripts/
RUN export LIBXCRYPT_VERSION=4.4.36 && \
    export LIBXCRYPT_HASH=b979838d5f1f238869d467484793b72b8bca64c4eae696fdbba0a9e0b6c28453 && \
    export LIBXCRYPT_DOWNLOAD_URL=https://github.com/besser82/libxcrypt/archive && \
    manylinux-entrypoint /build_scripts/install-libxcrypt.sh

FROM runtime_base AS build_base
COPY build_scripts/install-build-packages.sh /build_scripts/
RUN manylinux-entrypoint /build_scripts/install-build-packages.sh


FROM build_base AS build_git
COPY build_scripts/build-git.sh /build_scripts/
RUN export GIT_ROOT=git-2.45.2 && \
    export GIT_HASH=98b26090ed667099a3691b93698d1e213e1ded73d36a2fde7e9125fce28ba234 && \
    export GIT_DOWNLOAD_URL=https://www.kernel.org/pub/software/scm/git && \
    manylinux-entrypoint /build_scripts/build-git.sh


FROM build_base AS build_cpython_system_ssl
COPY build_scripts/build-sqlite3.sh /build_scripts/
RUN export SQLITE_AUTOCONF_ROOT=sqlite-autoconf-3460100 && \
    export SQLITE_AUTOCONF_HASH=67d3fe6d268e6eaddcae3727fce58fcc8e9c53869bdd07a0c61e38ddf2965071 && \
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
RUN export OPENSSL_ROOT=openssl-3.0.15 && \
    export OPENSSL_HASH=23c666d0edf20f14249b3d8f0368acaee9ab585b09e1de82107c66e1f3ec9533 && \
    export OPENSSL_DOWNLOAD_URL=https://github.com/openssl/openssl/releases/download/${OPENSSL_ROOT} && \
    manylinux-entrypoint /build_scripts/build-openssl.sh


FROM build_cpython_system_ssl AS build_cpython36
COPY build_scripts/cpython-pubkeys.txt /build_scripts/cpython-pubkeys.txt
RUN manylinux-entrypoint /build_scripts/build-cpython.sh 3.6.15

FROM build_cpython_system_ssl AS build_cpython37
COPY build_scripts/cpython-pubkeys.txt /build_scripts/cpython-pubkeys.txt
RUN manylinux-entrypoint /build_scripts/build-cpython.sh 3.7.17


FROM build_cpython AS build_cpython38
COPY build_scripts/ambv-pubkey.txt /build_scripts/cpython-pubkeys.txt
RUN manylinux-entrypoint /build_scripts/build-cpython.sh 3.8.20

FROM build_cpython AS build_cpython39
COPY build_scripts/ambv-pubkey.txt /build_scripts/cpython-pubkeys.txt
RUN manylinux-entrypoint /build_scripts/build-cpython.sh 3.9.20

FROM build_cpython AS build_cpython310
COPY build_scripts/cpython-pubkey-310-311.txt /build_scripts/cpython-pubkeys.txt
RUN manylinux-entrypoint /build_scripts/build-cpython.sh 3.10.15

FROM build_cpython AS build_cpython311
COPY build_scripts/cpython-pubkey-310-311.txt /build_scripts/cpython-pubkeys.txt
RUN manylinux-entrypoint /build_scripts/build-cpython.sh 3.11.10

FROM build_cpython AS build_cpython312
COPY build_scripts/cpython-pubkey-312-313.txt /build_scripts/cpython-pubkeys.txt
RUN manylinux-entrypoint /build_scripts/build-cpython.sh 3.12.7

FROM build_cpython AS build_cpython313
COPY build_scripts/cpython-pubkey-312-313.txt /build_scripts/cpython-pubkeys.txt
RUN manylinux-entrypoint /build_scripts/build-cpython.sh 3.13.0

FROM build_cpython AS build_cpython313_nogil
COPY build_scripts/cpython-pubkey-312-313.txt /build_scripts/cpython-pubkeys.txt
RUN manylinux-entrypoint /build_scripts/build-cpython.sh 3.13.0 nogil


FROM runtime_base
COPY --from=build_git /manylinux-rootfs /
COPY --from=build_cpython_system_ssl /manylinux-rootfs /
COPY build_scripts /opt/_internal/build_scripts/
RUN --mount=type=bind,target=/build_cpython36,from=build_cpython36 \
    --mount=type=bind,target=/build_cpython37,from=build_cpython37 \
    --mount=type=bind,target=/build_cpython38,from=build_cpython38 \
    --mount=type=bind,target=/build_cpython39,from=build_cpython39 \
    --mount=type=bind,target=/build_cpython310,from=build_cpython310 \
    --mount=type=bind,target=/build_cpython311,from=build_cpython311 \
    --mount=type=bind,target=/build_cpython312,from=build_cpython312 \
    --mount=type=bind,target=/build_cpython313,from=build_cpython313 \
    --mount=type=bind,target=/build_cpython313_nogil,from=build_cpython313_nogil \
    mkdir -p /opt/_internal && \
    cp -rf /build_cpython*/opt/_internal/* /opt/_internal/ && \
    manylinux-entrypoint /opt/_internal/build_scripts/finalize.sh \
      pp39-pypy39_pp73 \
      pp310-pypy310_pp73

ENV SSL_CERT_FILE=/opt/_internal/certs.pem

CMD ["/bin/bash"]

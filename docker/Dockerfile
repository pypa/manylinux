# default to latest supported policy, x86_64
ARG BASEIMAGE=amd64/almalinux:9
ARG POLICY=manylinux_2_34
ARG PLATFORM=x86_64
ARG DEVTOOLSET_ROOTPATH=/opt/rh/gcc-toolset-14/root
ARG LD_LIBRARY_PATH_ARG=${DEVTOOLSET_ROOTPATH}/usr/lib64:${DEVTOOLSET_ROOTPATH}/usr/lib:${DEVTOOLSET_ROOTPATH}/usr/lib64/dyninst:${DEVTOOLSET_ROOTPATH}/usr/lib/dyninst
ARG PREPEND_PATH=/usr/local/bin:${DEVTOOLSET_ROOTPATH}/usr/bin:
ARG MANYLINUX_BUILDARCH=${BUILDARCH}
ARG MANYLINUX_DISABLE_CLANG=0
ARG MANYLINUX_DISABLE_CLANG_FOR_CPYTHON=0
ARG MANYLINUX_CLANG_VERSION=21.1.8.1
ARG MANYLINUX_COSIGN_VERSION=3.0.4


FROM $BASEIMAGE AS runtime_base_packages
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
     /opt/_internal/build_scripts/

RUN /opt/_internal/build_scripts/install-entrypoint.sh
COPY manylinux-entrypoint /usr/local/bin/manylinux-entrypoint
ENTRYPOINT ["manylinux-entrypoint"]

COPY build_scripts/install-runtime-packages.sh /opt/_internal/build_scripts/
RUN manylinux-entrypoint /opt/_internal/build_scripts/install-runtime-packages.sh


# prepare cross-compilation support
FROM --platform=linux/${MANYLINUX_BUILDARCH} ghcr.io/mayeut/static-clang:${MANYLINUX_CLANG_VERSION} AS static_clang_bin
FROM runtime_base_packages AS static_clang_prepare
ARG MANYLINUX_DISABLE_CLANG
COPY build_scripts/install-clang-static.sh /opt/_internal/build_scripts/
RUN --mount=type=bind,target=/clang,from=static_clang_bin \
    mkdir -p /tmp/cross-compiler && \
    cp -rf /clang/opt/clang/* /tmp/cross-compiler/ && \
    /opt/_internal/build_scripts/install-clang-static.sh /tmp/cross-compiler
FROM scratch AS static_clang
COPY --from=static_clang_prepare /tmp/cross-compiler /


FROM runtime_base_packages AS runtime_base
COPY build_scripts/install-autoconf.sh /opt/_internal/build_scripts/
RUN --mount=type=bind,from=static_clang,target=/tmp/cross-compiler,ro \
    export AUTOCONF_ROOT=autoconf-2.72 && \
    export AUTOCONF_HASH=afb181a76e1ee72832f6581c0eddf8df032b83e2e0239ef79ebedc4467d92d6e && \
    export AUTOCONF_DOWNLOAD_URL=https://ftpmirror.gnu.org/gnu/autoconf && \
    /tmp/cross-compiler/entrypoint /opt/_internal/build_scripts/install-autoconf.sh

COPY build_scripts/install-automake.sh /opt/_internal/build_scripts/
RUN --mount=type=bind,from=static_clang,target=/tmp/cross-compiler,ro \
    export AUTOMAKE_ROOT=automake-1.18.1 && \
    export AUTOMAKE_HASH=63e585246d0fc8772dffdee0724f2f988146d1a3f1c756a3dc5cfbefa3c01915 && \
    export AUTOMAKE_DOWNLOAD_URL=https://ftpmirror.gnu.org/gnu/automake && \
    /tmp/cross-compiler/entrypoint /opt/_internal/build_scripts/install-automake.sh

COPY build_scripts/install-libtool.sh /opt/_internal/build_scripts/
RUN --mount=type=bind,from=static_clang,target=/tmp/cross-compiler,ro \
    export LIBTOOL_ROOT=libtool-2.5.4 && \
    export LIBTOOL_HASH=da8ebb2ce4dcf46b90098daf962cffa68f4b4f62ea60f798d0ef12929ede6adf && \
    export LIBTOOL_DOWNLOAD_URL=https://ftpmirror.gnu.org/gnu/libtool && \
    /tmp/cross-compiler/entrypoint /opt/_internal/build_scripts/install-libtool.sh

COPY build_scripts/install-libxcrypt.sh /opt/_internal/build_scripts/
RUN --mount=type=bind,from=static_clang,target=/tmp/cross-compiler,ro \
    export LIBXCRYPT_VERSION=4.5.2 && \
    export LIBXCRYPT_HASH=71513a31c01a428bccd5367a32fd95f115d6dac50fb5b60c779d5c7942aec071 && \
    export LIBXCRYPT_DOWNLOAD_URL=https://github.com/besser82/libxcrypt/releases/download && \
    /tmp/cross-compiler/entrypoint /opt/_internal/build_scripts/install-libxcrypt.sh


FROM runtime_base AS build_base
COPY build_scripts/install-build-packages.sh /opt/_internal/build_scripts/
RUN manylinux-entrypoint /opt/_internal/build_scripts/install-build-packages.sh


FROM build_base AS build_base_openssl
COPY build_scripts/build-openssl.sh /opt/_internal/build_scripts/
RUN --mount=type=bind,from=static_clang,target=/tmp/cross-compiler,ro \
    export OPENSSL_ROOT=openssl-3.5.5 && \
    export OPENSSL_HASH=b28c91532a8b65a1f983b4c28b7488174e4a01008e29ce8e69bd789f28bc2a89 && \
    export OPENSSL_DOWNLOAD_URL=https://github.com/openssl/openssl/releases/download/${OPENSSL_ROOT} && \
    /tmp/cross-compiler/entrypoint /opt/_internal/build_scripts/build-openssl.sh


FROM build_base_openssl AS build_git
COPY build_scripts/build-curl.sh /opt/_internal/build_scripts/
RUN --mount=type=bind,from=static_clang,target=/tmp/cross-compiler,ro \
    export CURL_ROOT=curl-8.18.0 && \
    export CURL_HASH=e9274a5f8ab5271c0e0e6762d2fce194d5f98acc568e4ce816845b2dcc0cf88f && \
    export CURL_DOWNLOAD_URL=https://curl.haxx.se/download && \
    /tmp/cross-compiler/entrypoint /opt/_internal/build_scripts/build-curl.sh
COPY build_scripts/build-git.sh /opt/_internal/build_scripts/
RUN --mount=type=bind,from=static_clang,target=/tmp/cross-compiler,ro \
    export GIT_ROOT=git-2.53.0 && \
    export GIT_HASH=429dc0f5fe5f14109930cdbbb588c5d6ef5b8528910f0d738040744bebdc6275 && \
    export GIT_DOWNLOAD_URL=https://www.kernel.org/pub/software/scm/git && \
    /tmp/cross-compiler/entrypoint /opt/_internal/build_scripts/build-git.sh


FROM build_base AS build_sqlite3
COPY build_scripts/build-sqlite3.sh /opt/_internal/build_scripts/
RUN --mount=type=bind,from=static_clang,target=/tmp/cross-compiler,ro \
    export SQLITE_AUTOCONF_ROOT=sqlite-autoconf-3510200 && \
    export SQLITE_AUTOCONF_HASH=fbd89f866b1403bb66a143065440089dd76100f2238314d92274a082d4f2b7bb && \
    export SQLITE_AUTOCONF_DOWNLOAD_URL=https://www.sqlite.org/2026 && \
    /tmp/cross-compiler/entrypoint /opt/_internal/build_scripts/build-sqlite3.sh


FROM build_base AS build_tcl_tk
COPY build_scripts/build-tcltk.sh /opt/_internal/build_scripts/
RUN --mount=type=bind,from=static_clang,target=/tmp/cross-compiler,ro \
    export TCL_ROOT=tcl8.6.17 && \
    export TCL_HASH=a3903371efcce8a405c5c245d029e9f6850258a60fa3761c4d58995610949b31 && \
    export TCL_DOWNLOAD_URL=https://prdownloads.sourceforge.net/tcl && \
    export TK_ROOT=tk8.6.17 && \
    export TK_HASH=e4982df6f969c08bf9dd858a6891059b4a3f50dc6c87c10abadbbe2fc4838946 && \
    /tmp/cross-compiler/entrypoint /opt/_internal/build_scripts/build-tcltk.sh


FROM build_base AS build_mpdecimal
COPY build_scripts/build-mpdecimal.sh /opt/_internal/build_scripts/
RUN --mount=type=bind,from=static_clang,target=/tmp/cross-compiler,ro \
    export MPDECIMAL_ROOT=mpdecimal-4.0.1 && \
    export MPDECIMAL_HASH=96d33abb4bb0070c7be0fed4246cd38416188325f820468214471938545b1ac8 && \
    export MPDECIMAL_DOWNLOAD_URL=https://www.bytereef.org/software/mpdecimal/releases && \
    /tmp/cross-compiler/entrypoint /opt/_internal/build_scripts/build-mpdecimal.sh


FROM build_base AS build_zstd
COPY build_scripts/build-zstd.sh /opt/_internal/build_scripts/
RUN --mount=type=bind,from=static_clang,target=/tmp/cross-compiler,ro \
    export ZSTD_VERSION=1.5.7 && \
    export ZSTD_HASH=eb33e51f49a15e023950cd7825ca74a4a2b43db8354825ac24fc1b7ee09e6fa3 && \
    export ZSTD_DOWNLOAD_URL=https://github.com/facebook/zstd/releases/download && \
    /tmp/cross-compiler/entrypoint /opt/_internal/build_scripts/build-zstd.sh


FROM --platform=${BUILDPLATFORM} ghcr.io/sigstore/cosign/cosign:v${MANYLINUX_COSIGN_VERSION} AS cosign-bin


FROM build_base_openssl AS build_cpython
COPY --from=build_tcl_tk /manylinux-buildfs /
COPY --from=build_mpdecimal /manylinux-buildfs /
COPY --from=build_zstd /manylinux-buildfs /
COPY --from=build_sqlite3 /manylinux-buildfs /
RUN if command -v apk >/dev/null 2>&1; then ldconfig /; else ldconfig; fi
COPY --from=cosign-bin /ko-app/cosign /usr/local/bin/cosign
COPY build_scripts/build-cpython.sh /opt/_internal/build_scripts/


FROM build_cpython AS build_cpython39
ARG MANYLINUX_DISABLE_CLANG_FOR_CPYTHON
RUN --mount=type=bind,from=static_clang,target=/tmp/cross-compiler,ro \
    /tmp/cross-compiler/entrypoint /opt/_internal/build_scripts/build-cpython.sh lukasz@langa.pl https://github.com/login/oauth 3.9.25

FROM build_cpython AS build_cpython310
ARG MANYLINUX_DISABLE_CLANG_FOR_CPYTHON
RUN --mount=type=bind,from=static_clang,target=/tmp/cross-compiler,ro \
    /tmp/cross-compiler/entrypoint /opt/_internal/build_scripts/build-cpython.sh pablogsal@python.org https://accounts.google.com 3.10.19

FROM build_cpython AS build_cpython311
ARG MANYLINUX_DISABLE_CLANG_FOR_CPYTHON
RUN --mount=type=bind,from=static_clang,target=/tmp/cross-compiler,ro \
    /tmp/cross-compiler/entrypoint /opt/_internal/build_scripts/build-cpython.sh pablogsal@python.org https://accounts.google.com 3.11.14

FROM build_cpython AS build_cpython312
ARG MANYLINUX_DISABLE_CLANG_FOR_CPYTHON
RUN --mount=type=bind,from=static_clang,target=/tmp/cross-compiler,ro \
    /tmp/cross-compiler/entrypoint /opt/_internal/build_scripts/build-cpython.sh thomas@python.org https://accounts.google.com 3.12.12

FROM build_cpython AS build_cpython313
ARG MANYLINUX_DISABLE_CLANG_FOR_CPYTHON
RUN --mount=type=bind,from=static_clang,target=/tmp/cross-compiler,ro \
    /tmp/cross-compiler/entrypoint /opt/_internal/build_scripts/build-cpython.sh thomas@python.org https://accounts.google.com 3.13.12

FROM build_cpython AS build_cpython314
ARG MANYLINUX_DISABLE_CLANG_FOR_CPYTHON
RUN --mount=type=bind,from=static_clang,target=/tmp/cross-compiler,ro \
    /tmp/cross-compiler/entrypoint /opt/_internal/build_scripts/build-cpython.sh hugo@python.org https://github.com/login/oauth 3.14.3

FROM build_cpython AS build_cpython314_nogil
ARG MANYLINUX_DISABLE_CLANG_FOR_CPYTHON
RUN --mount=type=bind,from=static_clang,target=/tmp/cross-compiler,ro \
    /tmp/cross-compiler/entrypoint /opt/_internal/build_scripts/build-cpython.sh hugo@python.org https://github.com/login/oauth 3.14.3 nogil

FROM build_cpython AS build_cpython315
ARG MANYLINUX_DISABLE_CLANG_FOR_CPYTHON
RUN --mount=type=bind,from=static_clang,target=/tmp/cross-compiler,ro \
    /tmp/cross-compiler/entrypoint /opt/_internal/build_scripts/build-cpython.sh hugo@python.org https://github.com/login/oauth 3.15.0a5

FROM build_cpython AS build_cpython315_nogil
ARG MANYLINUX_DISABLE_CLANG_FOR_CPYTHON
RUN --mount=type=bind,from=static_clang,target=/tmp/cross-compiler,ro \
    /tmp/cross-compiler/entrypoint /opt/_internal/build_scripts/build-cpython.sh hugo@python.org https://github.com/login/oauth 3.15.0a5 nogil


FROM runtime_base
COPY --from=build_tcl_tk /manylinux-rootfs /
COPY --from=build_mpdecimal /manylinux-rootfs /
COPY --from=build_zstd /manylinux-rootfs /
COPY --from=build_sqlite3 /manylinux-rootfs /
COPY --from=build_git /manylinux-rootfs /
COPY build_scripts /opt/_internal/build_scripts/
RUN --mount=type=bind,target=/build_cpython39,from=build_cpython39 \
    --mount=type=bind,target=/build_cpython310,from=build_cpython310 \
    --mount=type=bind,target=/build_cpython311,from=build_cpython311 \
    --mount=type=bind,target=/build_cpython312,from=build_cpython312 \
    --mount=type=bind,target=/build_cpython313,from=build_cpython313 \
    --mount=type=bind,target=/build_cpython314,from=build_cpython314 \
    --mount=type=bind,target=/build_cpython314_nogil,from=build_cpython314_nogil \
    --mount=type=bind,target=/build_cpython315,from=build_cpython315 \
    --mount=type=bind,target=/build_cpython315_nogil,from=build_cpython315_nogil \
    mkdir -p /opt/_internal && \
    cp -rf /build_cpython*/opt/_internal/cpython* /opt/_internal/ && \
    if test -n "$(find /build_cpython315/opt/_internal -maxdepth 1 -name 'openssl*' -print -quit)"; then cp -rf /build_cpython315/opt/_internal/openssl* /opt/_internal/; fi && \
    manylinux-entrypoint /opt/_internal/build_scripts/finalize.sh \
      pp311-pypy311_pp73

COPY tests /opt/_internal/tests/

ENV SSL_CERT_FILE=/opt/_internal/certs.pem

CMD ["/bin/bash"]

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


# prepare cross-compilation support
FROM --platform=linux/${MANYLINUX_BUILDARCH} ghcr.io/mayeut/static-clang:21.1.3.0 AS static_clang_bin
FROM runtime_base_packages AS static_clang_prepare
ARG MANYLINUX_DISABLE_CLANG
COPY build_scripts/install-clang-static.sh /build_scripts/
RUN --mount=type=bind,target=/clang,from=static_clang_bin \
    mkdir -p /tmp/cross-compiler && \
    cp -rf /clang/opt/clang/* /tmp/cross-compiler/ && \
    /build_scripts/install-clang-static.sh /tmp/cross-compiler
FROM scratch AS static_clang
COPY --from=static_clang_prepare /tmp/cross-compiler /


FROM runtime_base_packages AS runtime_base
COPY build_scripts/install-autoconf.sh /build_scripts/
RUN --mount=type=bind,from=static_clang,target=/tmp/cross-compiler,ro \
    export AUTOCONF_ROOT=autoconf-2.72 && \
    export AUTOCONF_HASH=afb181a76e1ee72832f6581c0eddf8df032b83e2e0239ef79ebedc4467d92d6e && \
    export AUTOCONF_DOWNLOAD_URL=http://ftp.gnu.org/gnu/autoconf && \
    /tmp/cross-compiler/entrypoint /build_scripts/install-autoconf.sh

COPY build_scripts/install-automake.sh /build_scripts/
RUN --mount=type=bind,from=static_clang,target=/tmp/cross-compiler,ro \
    export AUTOMAKE_ROOT=automake-1.18.1 && \
    export AUTOMAKE_HASH=63e585246d0fc8772dffdee0724f2f988146d1a3f1c756a3dc5cfbefa3c01915 && \
    export AUTOMAKE_DOWNLOAD_URL=http://ftp.gnu.org/gnu/automake && \
    /tmp/cross-compiler/entrypoint /build_scripts/install-automake.sh

COPY build_scripts/install-libtool.sh /build_scripts/
RUN --mount=type=bind,from=static_clang,target=/tmp/cross-compiler,ro \
    export LIBTOOL_ROOT=libtool-2.5.4 && \
    export LIBTOOL_HASH=da8ebb2ce4dcf46b90098daf962cffa68f4b4f62ea60f798d0ef12929ede6adf && \
    export LIBTOOL_DOWNLOAD_URL=http://ftp.gnu.org/gnu/libtool && \
    /tmp/cross-compiler/entrypoint /build_scripts/install-libtool.sh

COPY build_scripts/install-libxcrypt.sh /build_scripts/
RUN --mount=type=bind,from=static_clang,target=/tmp/cross-compiler,ro \
    export LIBXCRYPT_VERSION=4.4.38 && \
    export LIBXCRYPT_HASH=80304b9c306ea799327f01d9a7549bdb28317789182631f1b54f4511b4206dd6 && \
    export LIBXCRYPT_DOWNLOAD_URL=https://github.com/besser82/libxcrypt/releases/download && \
    /tmp/cross-compiler/entrypoint /build_scripts/install-libxcrypt.sh


FROM runtime_base AS build_base
COPY build_scripts/install-build-packages.sh /build_scripts/
RUN manylinux-entrypoint /build_scripts/install-build-packages.sh


FROM build_base AS build_git
COPY build_scripts/build-curl.sh /build_scripts/
RUN --mount=type=bind,from=static_clang,target=/tmp/cross-compiler,ro \
    export CURL_ROOT=curl-8.16.0 && \
    export CURL_HASH=a21e20476e39eca5a4fc5cfb00acf84bbc1f5d8443ec3853ad14c26b3c85b970 && \
    export CURL_DOWNLOAD_URL=https://curl.haxx.se/download && \
    /tmp/cross-compiler/entrypoint /build_scripts/build-curl.sh
COPY build_scripts/build-git.sh /build_scripts/
RUN --mount=type=bind,from=static_clang,target=/tmp/cross-compiler,ro \
    export GIT_ROOT=git-2.51.1 && \
    export GIT_HASH=b049d79e6a6cb3d81334bf689af6301f4d4c884191dfae65d2bb314a90384831 && \
    export GIT_DOWNLOAD_URL=https://www.kernel.org/pub/software/scm/git && \
    /tmp/cross-compiler/entrypoint /build_scripts/build-git.sh


FROM build_base AS build_sqlite3
COPY build_scripts/build-sqlite3.sh /build_scripts/
RUN --mount=type=bind,from=static_clang,target=/tmp/cross-compiler,ro \
    export SQLITE_AUTOCONF_ROOT=sqlite-autoconf-3500400 && \
    export SQLITE_AUTOCONF_HASH=a3db587a1b92ee5ddac2f66b3edb41b26f9c867275782d46c3a088977d6a5b18 && \
    export SQLITE_AUTOCONF_DOWNLOAD_URL=https://www.sqlite.org/2025 && \
    /tmp/cross-compiler/entrypoint /build_scripts/build-sqlite3.sh


FROM build_base AS build_tcl_tk
COPY build_scripts/build-tcltk.sh /build_scripts/
RUN --mount=type=bind,from=static_clang,target=/tmp/cross-compiler,ro \
    export TCL_ROOT=tcl8.6.17 && \
    export TCL_HASH=a3903371efcce8a405c5c245d029e9f6850258a60fa3761c4d58995610949b31 && \
    export TCL_DOWNLOAD_URL=https://prdownloads.sourceforge.net/tcl && \
    export TK_ROOT=tk8.6.17 && \
    export TK_HASH=e4982df6f969c08bf9dd858a6891059b4a3f50dc6c87c10abadbbe2fc4838946 && \
    /tmp/cross-compiler/entrypoint /build_scripts/build-tcltk.sh


FROM build_base AS build_mpdecimal
COPY build_scripts/build-mpdecimal.sh /build_scripts/
RUN --mount=type=bind,from=static_clang,target=/tmp/cross-compiler,ro \
    export MPDECIMAL_ROOT=mpdecimal-4.0.0 && \
    export MPDECIMAL_HASH=942445c3245b22730fd41a67a7c5c231d11cb1b9936b9c0f76334fb7d0b4468c && \
    export MPDECIMAL_DOWNLOAD_URL=https://www.bytereef.org/software/mpdecimal/releases && \
    /tmp/cross-compiler/entrypoint /build_scripts/build-mpdecimal.sh


FROM --platform=${BUILDPLATFORM} ghcr.io/sigstore/cosign/cosign:v2.5.0 AS cosign-bin


FROM build_base AS build_cpython
COPY --from=build_tcl_tk /manylinux-buildfs /
COPY --from=build_mpdecimal /manylinux-buildfs /
COPY --from=build_sqlite3 /manylinux-buildfs /
RUN if command -v apk >/dev/null 2>&1; then ldconfig /; else ldconfig; fi
COPY build_scripts/build-openssl.sh /build_scripts/
RUN --mount=type=bind,from=static_clang,target=/tmp/cross-compiler,ro \
    export OPENSSL_ROOT=openssl-3.5.4 && \
    export OPENSSL_HASH=967311f84955316969bdb1d8d4b983718ef42338639c621ec4c34fddef355e99 && \
    export OPENSSL_DOWNLOAD_URL=https://github.com/openssl/openssl/releases/download/${OPENSSL_ROOT} && \
    /tmp/cross-compiler/entrypoint /build_scripts/build-openssl.sh
COPY --from=cosign-bin /ko-app/cosign /usr/local/bin/cosign
COPY build_scripts/build-cpython.sh /build_scripts/


FROM build_cpython AS build_cpython38
ARG MANYLINUX_DISABLE_CLANG_FOR_CPYTHON
RUN --mount=type=bind,from=static_clang,target=/tmp/cross-compiler,ro \
    /tmp/cross-compiler/entrypoint /build_scripts/build-cpython.sh lukasz@langa.pl https://github.com/login/oauth 3.8.20

FROM build_cpython AS build_cpython39
ARG MANYLINUX_DISABLE_CLANG_FOR_CPYTHON
RUN --mount=type=bind,from=static_clang,target=/tmp/cross-compiler,ro \
    /tmp/cross-compiler/entrypoint /build_scripts/build-cpython.sh lukasz@langa.pl https://github.com/login/oauth 3.9.24

FROM build_cpython AS build_cpython310
ARG MANYLINUX_DISABLE_CLANG_FOR_CPYTHON
RUN --mount=type=bind,from=static_clang,target=/tmp/cross-compiler,ro \
    /tmp/cross-compiler/entrypoint /build_scripts/build-cpython.sh pablogsal@python.org https://accounts.google.com 3.10.19

FROM build_cpython AS build_cpython311
ARG MANYLINUX_DISABLE_CLANG_FOR_CPYTHON
RUN --mount=type=bind,from=static_clang,target=/tmp/cross-compiler,ro \
    /tmp/cross-compiler/entrypoint /build_scripts/build-cpython.sh pablogsal@python.org https://accounts.google.com 3.11.14

FROM build_cpython AS build_cpython312
ARG MANYLINUX_DISABLE_CLANG_FOR_CPYTHON
RUN --mount=type=bind,from=static_clang,target=/tmp/cross-compiler,ro \
    /tmp/cross-compiler/entrypoint /build_scripts/build-cpython.sh thomas@python.org https://accounts.google.com 3.12.12

FROM build_cpython AS build_cpython313
ARG MANYLINUX_DISABLE_CLANG_FOR_CPYTHON
RUN --mount=type=bind,from=static_clang,target=/tmp/cross-compiler,ro \
    /tmp/cross-compiler/entrypoint /build_scripts/build-cpython.sh thomas@python.org https://accounts.google.com 3.13.9

FROM build_cpython AS build_cpython313_nogil
ARG MANYLINUX_DISABLE_CLANG_FOR_CPYTHON
RUN --mount=type=bind,from=static_clang,target=/tmp/cross-compiler,ro \
    /tmp/cross-compiler/entrypoint /build_scripts/build-cpython.sh thomas@python.org https://accounts.google.com 3.13.9 nogil

FROM build_cpython AS build_cpython314
ARG MANYLINUX_DISABLE_CLANG_FOR_CPYTHON
RUN --mount=type=bind,from=static_clang,target=/tmp/cross-compiler,ro \
    /tmp/cross-compiler/entrypoint /build_scripts/build-cpython.sh hugo@python.org https://github.com/login/oauth 3.14.0

FROM build_cpython AS build_cpython314_nogil
ARG MANYLINUX_DISABLE_CLANG_FOR_CPYTHON
RUN --mount=type=bind,from=static_clang,target=/tmp/cross-compiler,ro \
    /tmp/cross-compiler/entrypoint /build_scripts/build-cpython.sh hugo@python.org https://github.com/login/oauth 3.14.0 nogil


FROM runtime_base
COPY --from=build_tcl_tk /manylinux-rootfs /
COPY --from=build_mpdecimal /manylinux-rootfs /
COPY --from=build_sqlite3 /manylinux-rootfs /
COPY --from=build_git /manylinux-rootfs /
COPY build_scripts /opt/_internal/build_scripts/
RUN --mount=type=bind,target=/build_cpython38,from=build_cpython38 \
    --mount=type=bind,target=/build_cpython39,from=build_cpython39 \
    --mount=type=bind,target=/build_cpython310,from=build_cpython310 \
    --mount=type=bind,target=/build_cpython311,from=build_cpython311 \
    --mount=type=bind,target=/build_cpython312,from=build_cpython312 \
    --mount=type=bind,target=/build_cpython313,from=build_cpython313 \
    --mount=type=bind,target=/build_cpython313_nogil,from=build_cpython313_nogil \
    --mount=type=bind,target=/build_cpython314,from=build_cpython314 \
    --mount=type=bind,target=/build_cpython314_nogil,from=build_cpython314_nogil \
    mkdir -p /opt/_internal && \
    cp -rf /build_cpython*/opt/_internal/* /opt/_internal/ && \
    manylinux-entrypoint /opt/_internal/build_scripts/finalize.sh \
      pp311-pypy311_pp73

COPY tests /opt/_internal/tests/

ENV SSL_CERT_FILE=/opt/_internal/certs.pem

CMD ["/bin/bash"]

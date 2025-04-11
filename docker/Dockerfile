# default to latest supported policy, x86_64
ARG BASEIMAGE=amd64/almalinux:9
ARG POLICY=manylinux_2_34
ARG PLATFORM=x86_64
ARG DEVTOOLSET_ROOTPATH=/opt/rh/gcc-toolset-14/root
ARG LD_LIBRARY_PATH_ARG=${DEVTOOLSET_ROOTPATH}/usr/lib64:${DEVTOOLSET_ROOTPATH}/usr/lib:${DEVTOOLSET_ROOTPATH}/usr/lib64/dyninst:${DEVTOOLSET_ROOTPATH}/usr/lib/dyninst
ARG PREPEND_PATH=/usr/local/bin:${DEVTOOLSET_ROOTPATH}/usr/bin:

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
RUN export LIBXCRYPT_VERSION=4.4.38 && \
    export LIBXCRYPT_HASH=80304b9c306ea799327f01d9a7549bdb28317789182631f1b54f4511b4206dd6 && \
    export LIBXCRYPT_DOWNLOAD_URL=https://github.com/besser82/libxcrypt/releases/download && \
    manylinux-entrypoint /build_scripts/install-libxcrypt.sh

FROM runtime_base AS build_base
COPY build_scripts/install-build-packages.sh /build_scripts/
RUN manylinux-entrypoint /build_scripts/install-build-packages.sh


FROM build_base AS build_git
COPY build_scripts/build-curl.sh /build_scripts/
RUN export CURL_ROOT=curl-8.13.0 && \
    export CURL_HASH=c261a4db579b289a7501565497658bbd52d3138fdbaccf1490fa918129ab45bc && \
    export CURL_DOWNLOAD_URL=https://curl.haxx.se/download && \
    manylinux-entrypoint /build_scripts/build-curl.sh
COPY build_scripts/build-git.sh /build_scripts/
RUN export GIT_ROOT=git-2.49.0 && \
    export GIT_HASH=f8047f572f665bebeb637fd5f14678f31b3ca5d2ff9a18f20bd925bd48f75d3c && \
    export GIT_DOWNLOAD_URL=https://www.kernel.org/pub/software/scm/git && \
    manylinux-entrypoint /build_scripts/build-git.sh

FROM build_base AS build_sqlite3
COPY build_scripts/build-sqlite3.sh /build_scripts/
RUN export SQLITE_AUTOCONF_ROOT=sqlite-autoconf-3490100 && \
    export SQLITE_AUTOCONF_HASH=106642d8ccb36c5f7323b64e4152e9b719f7c0215acf5bfeac3d5e7f97b59254 && \
    export SQLITE_AUTOCONF_DOWNLOAD_URL=https://www.sqlite.org/2025 && \
    manylinux-entrypoint /build_scripts/build-sqlite3.sh

FROM build_base AS build_tcl_tk
COPY build_scripts/build-tcltk.sh /build_scripts/
RUN export TCL_ROOT=tcl8.6.16 && \
    export TCL_HASH=91cb8fa61771c63c262efb553059b7c7ad6757afa5857af6265e4b0bdc2a14a5 && \
    export TCL_DOWNLOAD_URL=https://prdownloads.sourceforge.net/tcl && \
    export TK_ROOT=tk8.6.16 && \
    export TK_HASH=be9f94d3575d4b3099d84bc3c10de8994df2d7aa405208173c709cc404a7e5fe && \
    manylinux-entrypoint /build_scripts/build-tcltk.sh

FROM build_base AS build_mpdecimal
COPY build_scripts/build-mpdecimal.sh /build_scripts/
RUN export MPDECIMAL_ROOT=mpdecimal-4.0.0 && \
    export MPDECIMAL_HASH=942445c3245b22730fd41a67a7c5c231d11cb1b9936b9c0f76334fb7d0b4468c && \
    export MPDECIMAL_DOWNLOAD_URL=https://www.bytereef.org/software/mpdecimal/releases && \
    manylinux-entrypoint /build_scripts/build-mpdecimal.sh


FROM --platform=${BUILDPLATFORM} ghcr.io/sigstore/cosign/cosign:v2.4.2 AS cosign-bin

FROM build_base AS build_cpython_system_ssl
COPY --from=build_tcl_tk /manylinux-buildfs /
COPY --from=build_mpdecimal /manylinux-buildfs /
COPY --from=build_sqlite3 /manylinux-buildfs /
COPY build_scripts/build-cpython.sh /build_scripts/
RUN if command -v apk >/dev/null 2>&1; then ldconfig /; else ldconfig; fi
COPY --from=cosign-bin /ko-app/cosign /usr/local/bin/cosign

FROM build_cpython_system_ssl AS build_cpython
COPY build_scripts/build-openssl.sh /build_scripts/
RUN export OPENSSL_ROOT=openssl-3.0.16 && \
    export OPENSSL_HASH=57e03c50feab5d31b152af2b764f10379aecd8ee92f16c985983ce4a99f7ef86 && \
    export OPENSSL_DOWNLOAD_URL=https://github.com/openssl/openssl/releases/download/${OPENSSL_ROOT} && \
    manylinux-entrypoint /build_scripts/build-openssl.sh


FROM build_cpython_system_ssl AS build_cpython36
COPY build_scripts/cpython-pubkeys.txt /build_scripts/cpython-pubkeys.txt
RUN manylinux-entrypoint /build_scripts/build-cpython.sh "" "" 3.6.15

FROM build_cpython_system_ssl AS build_cpython37
RUN manylinux-entrypoint /build_scripts/build-cpython.sh nad@python.org https://github.com/login/oauth 3.7.17

FROM build_cpython AS build_cpython38
RUN manylinux-entrypoint /build_scripts/build-cpython.sh lukasz@langa.pl https://github.com/login/oauth 3.8.20

FROM build_cpython AS build_cpython39
RUN manylinux-entrypoint /build_scripts/build-cpython.sh lukasz@langa.pl https://github.com/login/oauth 3.9.22

FROM build_cpython AS build_cpython310
RUN manylinux-entrypoint /build_scripts/build-cpython.sh pablogsal@python.org https://accounts.google.com 3.10.17

FROM build_cpython AS build_cpython311
RUN manylinux-entrypoint /build_scripts/build-cpython.sh pablogsal@python.org https://accounts.google.com 3.11.12

FROM build_cpython AS build_cpython312
RUN manylinux-entrypoint /build_scripts/build-cpython.sh thomas@python.org https://accounts.google.com 3.12.10

FROM build_cpython AS build_cpython313
RUN manylinux-entrypoint /build_scripts/build-cpython.sh thomas@python.org https://accounts.google.com 3.13.3

FROM build_cpython AS build_cpython313_nogil
RUN manylinux-entrypoint /build_scripts/build-cpython.sh thomas@python.org https://accounts.google.com 3.13.3 nogil


FROM runtime_base
COPY --from=build_tcl_tk /manylinux-rootfs /
COPY --from=build_mpdecimal /manylinux-rootfs /
COPY --from=build_sqlite3 /manylinux-rootfs /
COPY --from=build_git /manylinux-rootfs /
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
      pp310-pypy310_pp73 pp311-pypy311_pp73

ENV SSL_CERT_FILE=/opt/_internal/certs.pem

CMD ["/bin/bash"]

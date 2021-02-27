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
COPY build_scripts/install-entrypoint.sh build_scripts/update-system-packages.sh /build_scripts/
RUN bash /build_scripts/install-entrypoint.sh && rm -rf /build_scripts
COPY manylinux-entrypoint /usr/local/bin/manylinux-entrypoint
ENTRYPOINT ["manylinux-entrypoint"]

COPY build_scripts/install-runtime-packages.sh build_scripts/update-system-packages.sh /build_scripts/
RUN manylinux-entrypoint /build_scripts/install-runtime-packages.sh && rm -rf /build_scripts/

COPY build_scripts/build_utils.sh /build_scripts/

COPY build_scripts/install-autoconf.sh /build_scripts/
RUN export AUTOCONF_ROOT=autoconf-2.70 && \
    export AUTOCONF_HASH=f05f410fda74323ada4bdc4610db37f8dbd556602ba65bc843edb4d4d4a1b2b7 && \
    export AUTOCONF_DOWNLOAD_URL=http://ftp.gnu.org/gnu/autoconf && \
    manylinux-entrypoint /build_scripts/install-autoconf.sh

COPY build_scripts/install-automake.sh /build_scripts/
RUN export AUTOMAKE_ROOT=automake-1.16.3 && \
    export AUTOMAKE_HASH=ce010788b51f64511a1e9bb2a1ec626037c6d0e7ede32c1c103611b9d3cba65f && \
    export AUTOMAKE_DOWNLOAD_URL=http://ftp.gnu.org/gnu/automake && \
    manylinux-entrypoint /build_scripts/install-automake.sh

COPY build_scripts/install-libtool.sh /build_scripts/
RUN export LIBTOOL_ROOT=libtool-2.4.6 && \
    export LIBTOOL_HASH=e3bd4d5d3d025a36c21dd6af7ea818a2afcd4dfc1ea5a17b39d7854bcd0c06e3 && \
    export LIBTOOL_DOWNLOAD_URL=http://ftp.gnu.org/gnu/libtool && \
    manylinux-entrypoint /build_scripts/install-libtool.sh

COPY build_scripts/install-patchelf.sh /build_scripts/
RUN export PATCHELF_VERSION=0.12 && \
    export PATCHELF_HASH=3dca33fb862213b3541350e1da262249959595903f559eae0fbc68966e9c3f56 && \
    export PATCHELF_DOWNLOAD_URL=https://github.com/NixOS/patchelf/archive && \
    manylinux-entrypoint /build_scripts/install-patchelf.sh

COPY build_scripts/install-libxcrypt.sh /build_scripts/
RUN export LIBXCRYPT_VERSION=4.4.17 && \
    export LIBXCRYPT_HASH=7665168d0409574a03f7b484682e68334764c29c21ca5df438955a381384ca07 && \
    export LIBXCRYPT_DOWNLOAD_URL=https://github.com/besser82/libxcrypt/archive && \
    manylinux-entrypoint /build_scripts/install-libxcrypt.sh


FROM runtime_base AS build_base
COPY build_scripts/install-build-packages.sh /build_scripts/
RUN manylinux-entrypoint /build_scripts/install-build-packages.sh


FROM build_base AS build_git
COPY build_scripts/build-git.sh /build_scripts/
RUN export GIT_ROOT=git-2.30.0 && \
    export GIT_HASH=d24c4fa2a658318c2e66e25ab67cc30038a35696d2d39e6b12ceccf024de1e5e && \
    export GIT_DOWNLOAD_URL=https://www.kernel.org/pub/software/scm/git && \
    manylinux-entrypoint /build_scripts/build-git.sh


FROM build_base AS build_cmake
COPY build_scripts/build-cmake.sh /build_scripts/
RUN export CMAKE_VERSION=3.18.3 && \
    export CMAKE_HASH=2c89f4e30af4914fd6fb5d00f863629812ada848eee4e2d29ec7e456d7fa32e5 && \
    export CMAKE_DOWNLOAD_URL=https://github.com/Kitware/CMake/releases/download && \
    manylinux-entrypoint /build_scripts/build-cmake.sh


FROM build_base AS build_swig
COPY build_scripts/build-swig.sh /build_scripts/
RUN export SWIG_ROOT=swig-4.0.2 && \
    export SWIG_HASH=d53be9730d8d58a16bf0cbd1f8ac0c0c3e1090573168bfa151b01eb47fa906fc && \
    export SWIG_DOWNLOAD_URL=https://sourceforge.net/projects/swig/files/swig/${SWIG_ROOT} && \
    export PCRE_ROOT=pcre-8.44 && \
    export PCRE_HASH=aecafd4af3bd0f3935721af77b889d9024b2e01d96b58471bd91a3063fb47728 && \
    export PCRE_DOWNLOAD_URL=https://ftp.pcre.org/pub/pcre && \
    manylinux-entrypoint /build_scripts/build-swig.sh


FROM build_base AS build_cpython
COPY build_scripts/build-sqlite3.sh /build_scripts/
RUN export SQLITE_AUTOCONF_ROOT=sqlite-autoconf-3340000 && \
    export SQLITE_AUTOCONF_HASH=bf6db7fae37d51754737747aaaf413b4d6b3b5fbacd52bdb2d0d6e5b2edd9aee && \
    export SQLITE_AUTOCONF_DOWNLOAD_URL=https://www.sqlite.org/2020 && \
    manylinux-entrypoint /build_scripts/build-sqlite3.sh

COPY build_scripts/build-openssl.sh /build_scripts/
RUN export OPENSSL_ROOT=openssl-1.1.1j && \
    export OPENSSL_HASH=aaf2fcb575cdf6491b98ab4829abf78a3dec8402b8b81efc8f23c00d443981bf && \
    export OPENSSL_DOWNLOAD_URL=https://www.openssl.org/source && \
    manylinux-entrypoint /build_scripts/build-openssl.sh

COPY build_scripts/build-cpython.sh /build_scripts/


FROM build_cpython AS build_cpython35
COPY build_scripts/cpython-pubkeys.txt /build_scripts/cpython-pubkeys.txt
RUN manylinux-entrypoint gpg --import /build_scripts/cpython-pubkeys.txt
RUN manylinux-entrypoint /build_scripts/build-cpython.sh 3.5.10


FROM build_cpython AS build_cpython36
COPY build_scripts/cpython-pubkeys.txt /build_scripts/cpython-pubkeys.txt
RUN manylinux-entrypoint gpg --import /build_scripts/cpython-pubkeys.txt
RUN manylinux-entrypoint /build_scripts/build-cpython.sh 3.6.13


FROM build_cpython AS build_cpython37
COPY build_scripts/cpython-pubkeys.txt /build_scripts/cpython-pubkeys.txt
RUN manylinux-entrypoint gpg --import /build_scripts/cpython-pubkeys.txt
RUN manylinux-entrypoint /build_scripts/build-cpython.sh 3.7.10


FROM build_cpython AS build_cpython38
COPY build_scripts/ambv-pubkey.txt /build_scripts/ambv-pubkey.txt
RUN manylinux-entrypoint gpg --import /build_scripts/ambv-pubkey.txt
RUN manylinux-entrypoint /build_scripts/build-cpython.sh 3.8.8


FROM build_cpython AS build_cpython39
COPY build_scripts/ambv-pubkey.txt /build_scripts/ambv-pubkey.txt
RUN manylinux-entrypoint gpg --import /build_scripts/ambv-pubkey.txt
RUN manylinux-entrypoint /build_scripts/build-cpython.sh 3.9.2


FROM build_cpython AS all_cpython
COPY --from=build_cpython35 /opt/_internal /opt/_internal/
COPY --from=build_cpython36 /opt/_internal /opt/_internal/
COPY --from=build_cpython37 /opt/_internal /opt/_internal/
COPY --from=build_cpython38 /opt/_internal /opt/_internal/
COPY --from=build_cpython39 /opt/_internal /opt/_internal/
RUN hardlink -cv /opt/_internal


FROM runtime_base
COPY --from=build_git /manylinux-rootfs /
COPY --from=build_cmake /manylinux-rootfs /
COPY --from=build_swig /manylinux-rootfs /
COPY --from=build_cpython /manylinux-rootfs /
COPY --from=all_cpython /opt/_internal /opt/_internal/
COPY build_scripts/finalize.sh build_scripts/update-system-packages.sh build_scripts/python-tag-abi-tag.py build_scripts/requirements.txt build_scripts/requirements-tools.txt /build_scripts/
RUN manylinux-entrypoint /build_scripts/finalize.sh && rm -rf /build_scripts

ENV SSL_CERT_FILE=/opt/_internal/certs.pem

CMD ["/bin/bash"]

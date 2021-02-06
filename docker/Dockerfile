# default to latest supported policy, x86_64
ARG BASEIMAGE=amd64/centos:7
ARG POLICY=manylinux2014
ARG PLATFORM=x86_64
ARG DEVTOOLSET_ROOTPATH=/opt/rh/devtoolset-9/root
ARG LD_LIBRARY_PATH_ARG=${DEVTOOLSET_ROOTPATH}/usr/lib64:${DEVTOOLSET_ROOTPATH}/usr/lib:${DEVTOOLSET_ROOTPATH}/usr/lib64/dyninst:${DEVTOOLSET_ROOTPATH}/usr/lib/dyninst:/usr/local/lib64:/usr/local/lib
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

# setup entrypoint, this will wrap commands with `linux32` with i686 images
COPY build_scripts/install-entrypoint.sh /build_scripts/
RUN bash /build_scripts/install-entrypoint.sh && rm -rf build_scripts
COPY manylinux-entrypoint /usr/local/bin/manylinux-entrypoint
ENTRYPOINT ["manylinux-entrypoint"]

COPY build_scripts/install-runtime-packages.sh /build_scripts/
RUN manylinux-entrypoint /build_scripts/install-runtime-packages.sh && rm /build_scripts/install-runtime-packages.sh

COPY build_scripts/build_utils.sh /build_scripts/

COPY build_scripts/install-automake.sh /build_scripts/
RUN export AUTOMAKE_ROOT=automake-1.16.2 && \
    export AUTOMAKE_HASH=b2f361094b410b4acbf4efba7337bdb786335ca09eb2518635a09fb7319ca5c1 && \
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


FROM build_base AS build_cpython
COPY build_scripts/build-sqlite3.sh /build_scripts/
RUN export SQLITE_AUTOCONF_ROOT=sqlite-autoconf-3340000 && \
    export SQLITE_AUTOCONF_HASH=bf6db7fae37d51754737747aaaf413b4d6b3b5fbacd52bdb2d0d6e5b2edd9aee && \
    export SQLITE_AUTOCONF_DOWNLOAD_URL=https://www.sqlite.org/2020 && \
    manylinux-entrypoint /build_scripts/build-sqlite3.sh

COPY build_scripts/build-cpython.sh /build_scripts/


FROM build_cpython AS build_cpython35
COPY build_scripts/cpython-pubkeys.txt /build_scripts/cpython-pubkeys.txt
RUN manylinux-entrypoint gpg --import /build_scripts/cpython-pubkeys.txt
RUN manylinux-entrypoint /build_scripts/build-cpython.sh 3.5.10


FROM build_cpython AS build_cpython36
COPY build_scripts/cpython-pubkeys.txt /build_scripts/cpython-pubkeys.txt
RUN manylinux-entrypoint gpg --import /build_scripts/cpython-pubkeys.txt
RUN manylinux-entrypoint /build_scripts/build-cpython.sh 3.6.12


FROM build_cpython AS build_cpython37
COPY build_scripts/cpython-pubkeys.txt /build_scripts/cpython-pubkeys.txt
RUN manylinux-entrypoint gpg --import /build_scripts/cpython-pubkeys.txt
RUN manylinux-entrypoint /build_scripts/build-cpython.sh 3.7.9


FROM build_cpython AS build_cpython38
COPY build_scripts/ambv-pubkey.txt /build_scripts/ambv-pubkey.txt
RUN manylinux-entrypoint gpg --import /build_scripts/ambv-pubkey.txt
RUN manylinux-entrypoint /build_scripts/build-cpython.sh 3.8.7


FROM build_cpython AS build_cpython39
COPY build_scripts/ambv-pubkey.txt /build_scripts/ambv-pubkey.txt
RUN manylinux-entrypoint gpg --import /build_scripts/ambv-pubkey.txt
RUN manylinux-entrypoint /build_scripts/build-cpython.sh 3.9.1


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
COPY --from=build_cpython /manylinux-rootfs /
COPY --from=all_cpython /opt/_internal /opt/_internal/
COPY build_scripts/finalize.sh /build_scripts/finalize.sh
COPY build_scripts/python-tag-abi-tag.py /build_scripts/python-tag-abi-tag.py
COPY build_scripts/ssl-check.py /build_scripts/ssl-check.py
COPY build_scripts/manylinux-check.py /build_scripts/manylinux-check.py
COPY build_scripts/requirements.txt /build_scripts/requirements.txt
COPY build_scripts/requirements-tools.txt /build_scripts/requirements-tools.txt
RUN manylinux-entrypoint /build_scripts/finalize.sh && rm -rf /build_scripts

ENV SSL_CERT_FILE=/opt/_internal/certs.pem

CMD ["/bin/bash"]

# default to latest policy, x86_64
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

# first fixup mirrors, keep the script around
COPY build_scripts/fixup-mirrors.sh /usr/local/sbin/fixup-mirrors
RUN fixup-mirrors

# setup entrypoint, this will wrap commands with `linux32` with i686 images
COPY build_scripts/install-entrypoint.sh /build_scripts/install-entrypoint.sh
RUN /build_scripts/install-entrypoint.sh && rm -rf build_scripts
COPY manylinux-entrypoint /usr/local/bin/manylinux-entrypoint
ENTRYPOINT ["manylinux-entrypoint"]

COPY build_scripts/install-runtime-packages.sh /build_scripts/install-runtime-packages.sh
RUN manylinux-entrypoint /build_scripts/install-runtime-packages.sh && rm -rf /build_scripts

COPY build_scripts/build_utils.sh /build_scripts/build_utils.sh

COPY build_scripts/install-autoconf.sh /build_scripts/install-autoconf.sh
RUN manylinux-entrypoint /build_scripts/install-autoconf.sh

COPY build_scripts/install-automake.sh /build_scripts/install-automake.sh
RUN manylinux-entrypoint /build_scripts/install-automake.sh

COPY build_scripts/install-libtool.sh /build_scripts/install-libtool.sh
RUN manylinux-entrypoint /build_scripts/install-libtool.sh

COPY build_scripts/install-patchelf.sh /build_scripts/install-patchelf.sh
RUN manylinux-entrypoint /build_scripts/install-patchelf.sh

COPY build_scripts/install-libxcrypt.sh /build_scripts/install-libxcrypt.sh
RUN manylinux-entrypoint /build_scripts/install-libxcrypt.sh

CMD ["/bin/bash"]


FROM runtime_base AS build_base
COPY build_scripts/install-build-packages.sh /build_scripts/install-build-packages.sh
RUN manylinux-entrypoint /build_scripts/install-build-packages.sh


FROM build_base AS build_git
COPY build_scripts/build-git.sh /build_scripts/build-git.sh
RUN manylinux-entrypoint /build_scripts/build-git.sh


FROM build_base AS build_cmake
COPY build_scripts/build-cmake.sh /build_scripts/build-cmake.sh
RUN manylinux-entrypoint /build_scripts/build-cmake.sh


FROM build_base AS build_cpython
COPY build_scripts/build-sqlite3.sh /build_scripts/build-sqlite3.sh
RUN manylinux-entrypoint /build_scripts/build-sqlite3.sh

COPY build_scripts/build-openssl.sh /build_scripts/build-openssl.sh
RUN manylinux-entrypoint /build_scripts/build-openssl.sh

COPY build_scripts/build-cpython.sh /build_scripts/build-cpython.sh


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
RUN manylinux-entrypoint /build_scripts/build-cpython.sh 3.8.6

FROM build_cpython AS build_cpython39
COPY build_scripts/ambv-pubkey.txt /build_scripts/ambv-pubkey.txt
RUN manylinux-entrypoint gpg --import /build_scripts/ambv-pubkey.txt
RUN manylinux-entrypoint /build_scripts/build-cpython.sh 3.9.1

FROM runtime_base AS all_cpython
COPY --from=build_cpython35 /opt/_internal /opt/_internal/
COPY --from=build_cpython36 /opt/_internal /opt/_internal/
COPY --from=build_cpython37 /opt/_internal /opt/_internal/
COPY --from=build_cpython38 /opt/_internal /opt/_internal/
COPY --from=build_cpython39 /opt/_internal /opt/_internal/
COPY build_scripts/install-requirements.sh /build_scripts/install-requirements.sh
COPY build_scripts/requirements.txt /build_scripts/requirements.txt
RUN manylinux-entrypoint /build_scripts/install-requirements.sh


FROM runtime_base
COPY --from=build_git /manylinux/git /
COPY --from=build_cmake /manylinux/cmake /
COPY --from=build_cpython /manylinux/sqlite3 /
COPY --from=all_cpython /opt/_internal /opt/_internal/
COPY build_scripts/finalize.sh /build_scripts/finalize.sh
COPY build_scripts/python-tag-abi-tag.py /build_scripts/python-tag-abi-tag.py
COPY build_scripts/ssl-check.py /build_scripts/ssl-check.py
COPY build_scripts/manylinux-check.py /build_scripts/manylinux-check.py
COPY build_scripts/requirements.txt /build_scripts/requirements.txt
COPY build_scripts/requirements-tools.txt /build_scripts/requirements-tools.txt
RUN manylinux-entrypoint /build_scripts/finalize.sh && rm -rf /build_scripts
ENV SSL_CERT_FILE=/opt/_internal/certs.pem

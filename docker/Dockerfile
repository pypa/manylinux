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
COPY build_scripts/build_utils.sh /build_scripts/
COPY build_scripts/build_env_runtime.sh /build_scripts/
RUN manylinux-entrypoint /build_scripts/install-runtime-packages.sh

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
COPY build_scripts/*pubkey*.txt /build_scripts/
COPY build_scripts/build_utils.sh /build_scripts/
COPY build_scripts/build.sh /build_scripts/
COPY build_scripts/build_env.sh /build_scripts/
RUN manylinux-entrypoint bash build_scripts/build.sh && rm -rf build_scripts

FROM runtime_base
COPY --from=build_base /manylinux-rootfs /
COPY --from=build_base /opt/_internal /opt/_internal/
COPY build_scripts/build_utils.sh /build_scripts/build_utils.sh
COPY build_scripts/finalize.sh /build_scripts/finalize.sh
COPY build_scripts/python-tag-abi-tag.py /build_scripts/python-tag-abi-tag.py
COPY build_scripts/ssl-check.py /build_scripts/ssl-check.py
COPY build_scripts/manylinux-check.py /build_scripts/manylinux-check.py
COPY build_scripts/requirements.txt /build_scripts/requirements.txt
COPY build_scripts/requirements-tools.txt /build_scripts/requirements-tools.txt
RUN manylinux-entrypoint /build_scripts/finalize.sh && rm -rf /build_scripts

ENV SSL_CERT_FILE=/opt/_internal/certs.pem

CMD ["/bin/bash"]

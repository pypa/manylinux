# default to latest policy, x86_64
ARG BASEIMAGE=amd64/debian:9
ARG POLICY=manylinux_2_24
ARG PLATFORM=x86_64
ARG DEVTOOLSET_ROOTPATH=
ARG LD_LIBRARY_PATH_ARG=
ARG PREPEND_PATH=

FROM $BASEIMAGE
ARG POLICY
ARG PLATFORM
ARG DEVTOOLSET_ROOTPATH
ARG LD_LIBRARY_PATH_ARG
ARG PREPEND_PATH
LABEL maintainer="The ManyLinux project"

ENV AUDITWHEEL_ARCH=${PLATFORM} AUDITWHEEL_PLAT=${POLICY}_${PLATFORM}
ENV LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8
ENV DEVTOOLSET_ROOTPATH=${DEVTOOLSET_ROOTPATH}
ENV LD_LIBRARY_PATH=${LD_LIBRARY_PATH_ARG}
ENV PATH=${PREPEND_PATH}${PATH}
ENV PKG_CONFIG_PATH=/usr/local/lib/pkgconfig

# setup entrypoint, this will wrap commands with `linux32` with i686 images
COPY build_scripts/install-entrypoint.sh /build_scripts/install-entrypoint.sh
RUN bash /build_scripts/install-entrypoint.sh && rm -rf build_scripts
COPY entrypoint.sh /opt/manylinux/entrypoint.sh
ENTRYPOINT ["/opt/manylinux/entrypoint.sh"]

COPY build_scripts /build_scripts
RUN /opt/manylinux/entrypoint.sh bash build_scripts/build.sh && rm -rf build_scripts

ENV SSL_CERT_FILE=/opt/_internal/certs.pem

CMD ["/bin/bash"]

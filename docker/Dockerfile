ARG POLICY=manylinux2014
ARG PLATFORM=${TARGETARCH}
ARG PLATFORM=${PLATFORM/amd64/x86_64}
ARG PLATFORM=${PLATFORM/arm64/aarch64}
ARG PLATFORM=${PLATFORM/386/i686}
ARG BASEIMAGE=${PLATFORM}
ARG BASEIMAGE=${BASEIMAGE/i686/centos}
ARG BASEIMAGE=${BASEIMAGE/x86_64/centos}
ARG BASEIMAGE=${BASEIMAGE/aarch64/centos}
ARG BASEIMAGE=${BASEIMAGE/ppc64le/centos}
ARG BASEIMAGE=${BASEIMAGE/s390x/clefos}

FROM ${BASEIMAGE}:7 AS runtime_base
ARG POLICY
ARG PLATFORM
LABEL maintainer="The ManyLinux project"

ENV AUDITWHEEL_POLICY=${POLICY} AUDITWHEEL_ARCH=${PLATFORM} AUDITWHEEL_PLAT=${POLICY}_${PLATFORM}
ENV LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8

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

FROM scratch
COPY --from=runtime_base / /
LABEL \
    org.label-schema.schema-version="1.0" \
    org.label-schema.name="ManyLinux 2014 Base Image" \
    org.label-schema.vendor="The ManyLinux project" \
    org.label-schema.license="GPLv2" \
    org.label-schema.build-date="20241102" \
    org.opencontainers.image.title="ManyLinux 2014 Base Image" \
    org.opencontainers.image.vendor="The ManyLinux project" \
    org.opencontainers.image.licenses="GPL-2.0-only" \
    org.opencontainers.image.created="2024-11-02 00:00:00+00:00"
CMD ["/bin/bash"]

FROM centos:5

LABEL description="Base image for building portable Linux binaries using modern GCC"
LABEL maintainer="oleavr@frida.re"

ARG CORES=8
ARG DEVTOOLS_PREFIX=/opt/devtools
ARG DEVTOOLS_CC="$DEVTOOLS_PREFIX/bin/gcc"
ARG DEVTOOLS_CXX="$DEVTOOLS_PREFIX/bin/g++"

ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8

COPY build_scripts /build_scripts
RUN bash /build_scripts/build.sh && rm -r /build_scripts

ENV PATH="$DEVTOOLS_PREFIX/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    LD_LIBRARY_PATH="$DEVTOOLS_PREFIX/lib64:$DEVTOOLS_PREFIX/lib:/usr/local/lib64:/usr/local/lib" \
    CPP="$DEVTOOLS_PREFIX/bin/cpp" \
    CC="$DEVTOOLS_CC" \
    CXX="$DEVTOOLS_CXX" \
    LD="$DEVTOOLS_PREFIX/bin/ld.gold" \
    AR="$DEVTOOLS_PREFIX/bin/ar" \
    NM="$DEVTOOLS_PREFIX/bin/nm" \
    RANLIB="$DEVTOOLS_PREFIX/bin/ranlib" \
    STRIP="$DEVTOOLS_PREFIX/bin/strip" \
    OBJCOPY="$DEVTOOLS_PREFIX/bin/objcopy" \
    OBJDUMP="$DEVTOOLS_PREFIX/bin/objdump"

CMD ["/bin/bash"]

# See docker/glibc/
FROM quay.io/pypa/manylinux2010_centos-6-no-vsyscall
LABEL maintainer="The ManyLinux project"

ENV AUDITWHEEL_PLAT manylinux2010_x86_64
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8
ENV PATH /opt/rh/devtoolset-8/root/usr/bin:$PATH
ENV LD_LIBRARY_PATH /opt/rh/devtoolset-8/root/usr/lib64:/opt/rh/devtoolset-8/root/usr/lib:/opt/rh/devtoolset-8/root/usr/lib64/dyninst:/opt/rh/devtoolset-8/root/usr/lib/dyninst:/usr/local/lib64:/usr/local/lib
ENV PKG_CONFIG_PATH /usr/local/lib/pkgconfig

COPY build_scripts /build_scripts
RUN bash build_scripts/build.sh && rm -r build_scripts

ENV SSL_CERT_FILE=/opt/_internal/certs.pem

CMD ["/bin/bash"]

FROM centos:6 as centos-with-vsyscall

COPY ./build_scripts /build_scripts
RUN bash /build_scripts/rebuild-glibc-without-vsyscall.sh

FROM centos:6
LABEL maintainer="The Manylinux project"

COPY --from=centos-with-vsyscall /rpms /rpms

RUN yum -y install /rpms/* && rm -rf /rpms

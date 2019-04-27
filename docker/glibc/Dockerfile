FROM centos:6 as centos-with-vsyscall

COPY ./build_scripts /build_scripts
RUN bash /build_scripts/rebuild-glibc-without-vsyscall.sh

FROM centos:6
LABEL maintainer="The Manylinux project"

COPY --from=centos-with-vsyscall /rpms /rpms

RUN yum -y install /rpms/* && rm -rf /rpms && yum -y clean all && rm -rf /var/cache/yum/* && \
    # if we updated glibc, we need to strip locales again...
    localedef --list-archive | grep -v -i ^en_US.utf8 | xargs localedef --delete-from-archive && \
    mv -f /usr/lib/locale/locale-archive /usr/lib/locale/locale-archive.tmpl && \
    build-locale-archive && \
    find /usr/share/locale -mindepth 1 -maxdepth 1 -not \( -name 'en*' -or -name 'locale.alias' \) | xargs rm -rf

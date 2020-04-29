FROM centos:6
LABEL maintainer="The Manylinux project"

# do not install debuginfo and what x86_64 already provides
COPY --from=quay.io/pypa/manylinux2010_centos-6-with-vsyscall32:latest \
    /rpms/glibc-2.12-1.212.1.el6.i686.rpm \
    #/rpms/glibc-common-2.12-1.212.1.el6.i686.rpm \
    #/rpms/glibc-debuginfo-2.12-1.212.1.el6.i686.rpm \
    #/rpms/glibc-debuginfo-common-2.12-1.212.1.el6.i686.rpm \
    /rpms/glibc-devel-2.12-1.212.1.el6.i686.rpm \
    #/rpms/glibc-headers-2.12-1.212.1.el6.i686.rpm \
    /rpms/glibc-static-2.12-1.212.1.el6.i686.rpm \
    #/rpms/glibc-utils-2.12-1.212.1.el6.i686.rpm \
    #/rpms/nscd-2.12-1.212.1.el6.i686.rpm \
    /rpms/
# do not install debuginfo
COPY --from=quay.io/pypa/manylinux2010_centos-6-with-vsyscall64:latest \
    /rpms/glibc-2.12-1.212.1.el6.x86_64.rpm \
    /rpms/glibc-common-2.12-1.212.1.el6.x86_64.rpm \
    #/rpms/glibc-debuginfo-2.12-1.212.1.el6.x86_64.rpm \
    #/rpms/glibc-debuginfo-common-2.12-1.212.1.el6.x86_64.rpm \
    /rpms/glibc-devel-2.12-1.212.1.el6.x86_64.rpm \
    /rpms/glibc-headers-2.12-1.212.1.el6.x86_64.rpm \
    /rpms/glibc-static-2.12-1.212.1.el6.x86_64.rpm \
    /rpms/glibc-utils-2.12-1.212.1.el6.x86_64.rpm \
    /rpms/nscd-2.12-1.212.1.el6.x86_64.rpm \
    /rpms/

RUN yum install -y glibc.i686 glibc-devel.i686 glibc-static.i686 glibc.x86_64 glibc-devel.x86_64 glibc-static.x86_64 && \
    yum -y install /rpms/* && rm -rf /rpms && yum -y clean all && rm -rf /var/cache/yum/* && \
    # if we updated glibc, we need to strip locales again...
    localedef --list-archive | grep -v -i ^en_US.utf8 | xargs localedef --delete-from-archive && \
    mv -f /usr/lib/locale/locale-archive /usr/lib/locale/locale-archive.tmpl && \
    build-locale-archive && \
    find /usr/share/locale -mindepth 1 -maxdepth 1 -not \( -name 'en*' -or -name 'locale.alias' \) | xargs rm -rf

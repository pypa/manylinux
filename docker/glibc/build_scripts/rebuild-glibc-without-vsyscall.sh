#!/bin/sh
# Prep script for x86_64 that recompiles glibc without vsyscalls.

# Stop at any error, show all commands
set -ex

# Locate the prep directory
MY_DIR=/$(dirname "${BASH_SOURCE[0]}")

# glibc versions
ORIGINAL_GLIBC_VERSION=2.12-1.209
PATCHED_GLIBC_VERSION=2.12-1.209.1

# Source RPM topdir
SRPM_TOPDIR=/root/rpmbuild

# Source RPM download directory
DOWNLOADED_SRPMS=/root/srpms

# Include the CentOS source RPM repository.
# https://bugs.centos.org/view.php?id=1646
cp $MY_DIR/CentOS-source.repo /etc/yum.repos.d/CentOS-source.repo

# Extract and prepare the source
# https://blog.packagecloud.io/eng/2015/04/20/working-with-source-rpms/
yum -y update
yum -y install yum-utils rpm-build
yum-builddep -y glibc
mkdir $DOWNLOADED_SRPMS
# The glibc RPM's contents are owned by mockbuild
adduser mockbuild
# yumdownloader assumes the current working directory
(cd $DOWNLOADED_SRPMS && yumdownloader --source glibc)
rpm -ivh $DOWNLOADED_SRPMS/glibc-$ORIGINAL_GLIBC_VERSION.el6.src.rpm
# Prepare the source by applying Red Hat and CentOS patches
rpmbuild -bp $SRPM_TOPDIR/SPECS/glibc.spec

# Copy the vsyscall removal patch into place
cp $MY_DIR/remove-vsyscall.patch $SRPM_TOPDIR/SOURCES
# Patch the RPM spec file so that it uses the vsyscall removal patch
(cd $SRPM_TOPDIR/SPECS && patch -p2 < $MY_DIR/glibc.spec.patch)

# Build the RPMS
rpmbuild -ba $SRPM_TOPDIR/SPECS/glibc.spec

mv $SRPM_TOPDIR/RPMS/* /rpms/

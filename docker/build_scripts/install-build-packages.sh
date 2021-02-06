#!/bin/bash
# Top-level build script called from Dockerfile

# Stop at any error, show all commands
set -ex

# Set build environment variables
MY_DIR=$(dirname "${BASH_SOURCE[0]}")

# Dependencies for compiling Python that we want to remove from
# the final image after compiling Python
PYTHON_COMPILE_DEPS="zlib-devel bzip2-devel expat-devel ncurses-devel readline-devel tk-devel gdbm-devel libdb-devel libpcap-devel xz-devel openssl-devel keyutils-libs-devel krb5-devel libcom_err-devel libidn-devel curl-devel perl-devel libffi-devel kernel-devel"
CMAKE_DEPS="openssl-devel zlib-devel libcurl-devel"

# Development tools and libraries
yum -y install ${PYTHON_COMPILE_DEPS} ${CMAKE_DEPS}

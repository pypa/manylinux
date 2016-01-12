FROM centos:5.11
MAINTAINER The NumPy Project

# Base image (~ reproduce the packer base image)
RUN yum -y install gcc bzip2 make kernel-devel-`uname -r`
RUN yum -y install gcc-c++
RUN yum -y erase wireless-tools gtk2 libX11 hicolor-icon-theme avahi freetype bitstream-vera-fonts
RUN yum -y install curl wget
RUN yum -y clean all

# EPEL support
RUN wget https://dl.fedoraproject.org/pub/epel/5/x86_64/epel-release-5-4.noarch.rpm
RUN rpm -Uvh --replacepkgs epel-release-5*.rpm
RUN rm -f epel-release-5*.rpm

# Install python26
RUN yum install -y python26 python26-devel
RUN curl -L https://bootstrap.pypa.io/get-pip.py --output /tmp/get-pip.py
RUN /usr/bin/python2.6 /tmp/get-pip.py

# Dev toolset (for LLVM and other projects requiring C++11 support)
ADD devtoolset-repo.repo /etc/yum.repos.d/devtoolset-repo.repo
RUN yum -y install devtoolset-2-binutils devtoolset-2-gcc devtoolset-2-gcc-c++

# Tools required to build
RUN yum -y install git patch unzip bison yasm
RUN pip install virtualenv fabric
# gcc 4.4 is required to build recent scipy correctly (fortran)
RUN yum -y install gcc-gfortran gcc44 gcc44-c++ gcc44-gfortran
# Libraries we depend on
RUN yum -y install mesa-libGL-devel mesa-libGLU-devel libXt-devel cups-devel
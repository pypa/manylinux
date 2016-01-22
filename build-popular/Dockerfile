FROM quay.io/manylinux/manylinux:latest
MAINTAINER Robert T. McGibbon

ENV PATH /opt/3.5/bin:$PATH
ENV LD_LIBRARY_PATH /usr/local/lib:/usr/local/lib64:$LD_LIBRARY_PATH

# cffi
RUN yum install -y libffi-devel
RUN pip install cffi

# cryptography
RUN wget http://www.openssl.org/source/openssl-1.0.2e.tar.gz
RUN tar -xzvf openssl-1.0.2e.tar.gz
RUN (cd openssl-1.0.2e && ./config shared --prefix=/usr/local && make && make install)
RUN pip install cryptography

# libOpenBLAS (for numpy)
RUN wget http://github.com/xianyi/OpenBLAS/archive/v0.2.15.tar.gz -O v0.2.15.tar.gz
RUN tar -xzvf v0.2.15.tar.gz
RUN (cd OpenBLAS-0.2.15/ && make && make PREFIX=/usr/local/ install)

RUN pip install numpy
RUN pip install pandas
RUN pip install regex
RUN pip install pymongo

RUN yum install -y zeromq-devel
RUN pip install pyzmq --install-option="--zmq=/usr/lib"

RUN yum install -y libjpeg-devel zlib-devel
RUN pip install pillow

RUN wget http://downloads.sourceforge.net/libpng/libpng-1.6.20.tar.gz
RUN (tar -xzvf libpng-1.6.20.tar.gz && cd libpng-1.6.20 && ./configure --prefix=/usr/local && make && make install)
RUN wget http://downloads.sourceforge.net/freetype/freetype-2.6.2.tar.bz2
RUN (tar -xjvf freetype-2.6.2.tar.bz2 && cd freetype-2.6.2 && ./configure --prefix=/usr && make && make install)
RUN ln -s /usr/include/freetype2/ft2build.h /usr/include/

RUN pip install matplotlib -vv
RUN pip install scipy
RUN pip install scikit-learn
RUN pip install coverage
RUN pip install gnureadline
RUN pip install cython
RUN pip install psutil

RUN yum install -y zeromq-devel
RUN pip wheel pyzmq --build-option="--zmq=/usr/lib" -w original-wheels

# Collect all of the wheels at the end
RUN pip wheel -w original-wheels cffi cryptography numpy pandas regex pymongo pillow matplotlib scipy scikit-learn coverage gnureadline cython psutil
RUN ls original-wheels
RUN find original-wheels -name '*linux_x86_64.whl' | xargs -n1 auditwheel repair -w repaired-wheels
RUN for fn in repaired-wheels/*.whl; do auditwheel show $fn; done

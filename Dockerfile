# See branch manylinux2010_x86_64_centos6_no_vsyscall of pypa/manylinux
FROM ryan/manylinux2010
LABEL maintainer="ryan"

ENV PATH /opt/python/cp36-cp36m/bin:$DEVTOOLSET_ROOTPATH/usr/bin:$PATH
ENV LD_LIBRARY_PATH /opt/python/cp36-cp36m/lib:$DEVTOOLSET_ROOTPATH/usr/lib64:$DEVTOOLSET_ROOTPATH/usr/lib:$DEVTOOLSET_ROOTPATH/usr/lib64/dyninst:$DEVTOOLSET_ROOTPATH/usr/lib/dyninst:/usr/local/lib64:/usr/local/lib

RUN curl -sSf https://sh.rustup.rs | sh -s -- -y

COPY req.txt /req.txt
RUN pip3 install -r req.txt

CMD ["/bin/bash"]

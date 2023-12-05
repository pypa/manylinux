Build Python With Shared Libraries - manylinux
==============================================

This fork of `pypa/manylinux <https://github.com/pypa/manylinux/>`_ builds a ManyLinux2014 docker image with ``--enable-shared`` and was inspred by `pypa/manylinux #1185 <https://github.com/pypa/manylinux/pull/1185>`_.

To improve build time and decrease image size, only Python 3.10 is
built. Additionally, images are tagged `femorph/...`, something you might want
to modify if you use the build script.

Usage::

  PLATFORM=$(uname -m) POLICY=manylinux2014 ./build.sh

Note that many build steps features have been removed, including building PyPy.

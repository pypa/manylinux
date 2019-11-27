manylinux
=========

Email: wheel-builders@python.org

Archives: https://mail.python.org/mailman/listinfo/wheel-builders

Older archives: https://groups.google.com/forum/#!forum/manylinux-discuss

The goal of the manylinux project is to provide a convenient way to
distribute binary Python extensions as wheels on Linux. This effort
has produced `PEP 513 <https://www.python.org/dev/peps/pep-0513/>`_ which
is further enhanced by `PEP 571 <https://www.python.org/dev/peps/pep-0571/>`_
defining ``manylinux2010_x86_64`` and ``manylinux2010_i686`` platform tags.

PEP 513 defined ``manylinux1_x86_64`` and ``manylinux1_i686`` platform tags
and the wheels were built on Centos5. Centos5 reached End of Life (EOL) on
March 31st, 2017 and thus PEP 571 was proposed.

Code and details regarding ``manylinux1`` can be found here:
`manylinux1 <https://github.com/pypa/manylinux/tree/manylinux1>`_.

Wheel packages compliant with those tags can be uploaded to
`PyPI <https://pypi.python.org>`_ (for instance with `twine
<https://pypi.python.org/pypi/twine>`_) and can be installed with
**pip 19.0 and later**.

The manylinux2010 tags allow projects to distribute wheels that are
automatically installed (and work!) on the vast majority of desktop
and server Linux distributions.

This repository hosts several manylinux-related things:


Docker images
-------------

.. image:: https://travis-ci.org/pypa/manylinux.svg?branch=master
   :target: https://travis-ci.org/organization/pypa

Building manylinux-compatible wheels is not trivial; as a general
rule, binaries built on one Linux distro will only work on other Linux
distros that are the same age or newer. Therefore, if we want to make
binaries that run on most Linux distros, we have to use a very old
distro -- CentOS 6.


Rather than forcing you to install CentOS 6 yourself, install Python,
etc., we provide a `Docker <https://docker.com/>`_ image where we've
done the work for you:

manylinux1
~~~~~~~~~~

x86-64 image: ``quay.io/pypa/manylinux1_x86_64``

.. image:: https://quay.io/repository/pypa/manylinux1_x86_64/status
   :target: https://quay.io/repository/pypa/manylinux1_x86_64

i686 image: ``quay.io/pypa/manylinux1_i386``

.. image:: https://quay.io/repository/pypa/manylinux1_i686/status
   :target: https://quay.io/repository/pypa/manylinux1_i686

manylinux2010
~~~~~~~~~~~~~

x86-64 image: ``quay.io/pypa/manylinux2010_x86_64``

.. image:: https://quay.io/repository/pypa/manylinux2010_x86_64/status
   :target: https://quay.io/repository/pypa/manylinux2010_x86_64

i686 image: ``quay.io/pypa/manylinux2010_i686``

.. image:: https://quay.io/repository/pypa/manylinux2010_i686/status
   :target: https://quay.io/repository/pypa/manylinux2010_i686

manylinux2014
~~~~~~~~~~~~~

x86_64 image: ``quay.io/pypa/manylinux2014_x86_64``

.. image:: https://quay.io/repository/pypa/manylinux2014_x86_64/status
   :target: https://quay.io/repository/pypa/manylinux2014_x86_64

i686 image: ``quay.io/pypa/manylinux2014_i686``

.. image:: https://quay.io/repository/pypa/manylinux2014_i686/status
   :target: https://quay.io/repository/pypa/manylinux2014_i686

aarch64 image: ``quay.io/pypa/manylinux2014_aarch64``

.. image:: https://quay.io/repository/pypa/manylinux2014_aarch64/status
   :target: https://quay.io/repository/pypa/manylinux2014_aarch64

ppc64le image: ``quay.io/pypa/manylinux2014_ppc64le``

.. image:: https://quay.io/repository/pypa/manylinux2014_ppc64le/status
   :target: https://quay.io/repository/pypa/manylinux2014_ppc64le

s390x image: ``quay.io/pypa/manylinux2014_s390x``

.. image:: https://quay.io/repository/pypa/manylinux2014_s390x/status
   :target: https://quay.io/repository/pypa/manylinux2014_s390x

These images are rebuilt using Travis-CI on every commit to this
repository; see the
`docker/ <https://github.com/pypa/manylinux/tree/master/docker>`_
directory for source code.

The images currently contain:

- CPython 2.7, 3.4, 3.5, 3.6, 3.7 & 3.8, installed in
  ``/opt/python/<python tag>-<abi tag>``. The directories are named
  after the PEP 425 tags for each environment --
  e.g. ``/opt/python/cp27-cp27mu`` contains a wide-unicode CPython 2.7
  build, and can be used to produce wheels named like
  ``<pkg>-<version>-cp27-cp27mu-<arch>.whl``.

- Devel packages for all the libraries that PEP 571 allows you to
  assume are present on the host system

- The `auditwheel <https://pypi.python.org/pypi/auditwheel>`_ tool

Note that prior to CPython 3.3, there were two ABI-incompatible ways
of building CPython: ``--enable-unicode=ucs2`` and
``--enable-unicode=ucs4``. We provide both versions
(e.g. ``/opt/python/cp27-cp27m`` for narrow-unicode,
``/opt/python/cp27-cp27mu`` for wide-unicode). NB: essentially all
Linux distributions configure CPython in ``mu``
(``--enable-unicode=ucs4``) mode, but ``--enable-unicode=ucs2`` builds
are also encountered in the wild. Other less common or virtually
unheard of flag combinations (such as ``--with-pydebug`` (``d``) and
``--without-pymalloc`` (absence of ``m``)) are not provided.

Note that `starting with CPython 3.8 <https://docs.python.org/dev/whatsnew/3.8.html#build-and-c-api-changes>`_,
default ``sys.abiflags`` became an empty string: the ``m`` flag for pymalloc
became useless (builds with and without pymalloc are ABI compatible) and so has
been removed. (e.g. ``/opt/python/cp38-cp38``)

Building Docker images
----------------------

To build the Docker images, you will need to fetch the tarballs to
``docker/sources/`` prior to building. This can be done with the
provided prefetch script, after which you can proceed with building.
Please run the following command from the current (root) directory::

    $ PLATFORM=$(uname -m) TRAVIS_COMMIT=latest ./build.sh

Example
-------

An example project which builds 64-bit wheels for each Python interpreter
version can be found here: https://github.com/pypa/python-manylinux-demo. The
repository also contains demo to build 32-bit and 64-bit wheels with ``manylinux1``
tags.

This demonstrates how to use these docker images in conjunction with auditwheel
to build manylinux-compatible wheels using the free `travis ci <https://travis-ci.org/>`_
continuous integration service.

(NB: for the 32-bit images running on a 64-bit host machine, it's necessary to run
everything under the command line program `linux32`, which changes reported architecture
in new program environment. See `this example invocation
<https://github.com/pypa/python-manylinux-demo/blob/master/.travis.yml#L14>`_)

The PEP itself
--------------

The official version of `PEP 513
<https://www.python.org/dev/peps/pep-0513/>`_ is stored in the `PEP
repository <https://github.com/python/peps>`_, but we also have our
`own copy here
<https://github.com/pypa/manylinux/tree/master/pep-513.rst>`_. This is
where the PEP was originally written, so if for some reason you really
want to see the full history of edits it went through, then this is
the place to look.

The proposal to upgrade ``manylinux1`` to ``manylinux2010`` after Centos5
reached EOL was discussed in `PEP 571 <https://www.python.org/dev/peps/pep-0571/>`_.

This repo also has some analysis code that was used when putting
together the original proposal in the ``policy-info/`` directory.

If you want to read the full discussion that led to the original
policy, then lots of that is here:
https://groups.google.com/forum/#!forum/manylinux-discuss

The distutils-sig archives for January 2016 also contain several
threads.


Code of Conduct
===============

Everyone interacting in the manylinux project's codebases, issue
trackers, chat rooms, and mailing lists is expected to follow the
`PyPA Code of Conduct`_.

.. _PyPA Code of Conduct: https://www.pypa.io/en/latest/code-of-conduct

manylinux
=========

Email: wheel-builders@python.org

Archives: https://mail.python.org/mailman/listinfo/wheel-builders

Older archives: https://groups.google.com/forum/#!forum/manylinux-discuss

The goal of the manylinux project is to provide a convenient way to
distribute binary Python extensions as wheels on Linux. This effort
has produced `PEP 513 <https://www.python.org/dev/peps/pep-0513/>`_ which
is further enhanced by `PEP 571 <https://www.python.org/dev/peps/pep-0571/>`_
and now `PEP 599 <https://www.python.org/dev/peps/pep-0599/>`_ defining
``manylinux2014_*`` platform tags.

PEP 513 defined ``manylinux1_x86_64`` and ``manylinux1_i686`` platform tags
and the wheels were built on Centos5. Centos5 reached End of Life (EOL) on
March 31st, 2017 and thus PEP 571 was proposed.

PEP 571 defined ``manylinux2010_x86_64`` and ``manylinux2010_i686`` platform
tags and the wheels were built on Centos6. Centos6 will reach End of Life (EOL)
on November 30th, 2020.

PEP 599 defines the following platform tags:

- ``manylinux2014_x86_64``

- ``manylinux2014_i686``

- ``manylinux2014_aarch64``

- ``manylinux2014_armv7l``

- ``manylinux2014_ppc64``

- ``manylinux2014_ppc64le``

- ``manylinux2014_s390x``

Wheels are built on CentOS 7 which will reach End of Life (EOL)
on June 30th, 2024.

Code and details regarding ``manylinux1`` can be found here:
`manylinux1 <https://github.com/pypa/manylinux/tree/manylinux1>`_.

Code and details regarding ``manylinux2010`` can be found here:
`manylinux2010 <https://github.com/pypa/manylinux/tree/master>`_.

Wheel packages compliant with those tags can be uploaded to
`PyPI <https://pypi.python.org>`_ (for instance with `twine
<https://pypi.python.org/pypi/twine>`_) and can be installed with
**pip 19.3 and later**.

The manylinux2014 tags allow projects to distribute wheels that are
automatically installed (and work!) on the vast majority of desktop
and server Linux distributions.

This repository hosts several manylinux-related things:


Docker images
-------------

.. image:: https://travis-ci.org/pypa/manylinux.svg?branch=manylinux2014
   :target: https://travis-ci.org/pypa/manylinux

Building manylinux-compatible wheels is not trivial; as a general
rule, binaries built on one Linux distro will only work on other Linux
distros that are the same age or newer. Therefore, if we want to make
binaries that run on most Linux distros, we have to use an old enough
distro -- CentOS 7.


Rather than forcing you to install CentOS 7 yourself, install Python,
etc., we provide `Docker <https://docker.com/>`_ images where we've
done the work for you:

x86_64 image: ``quay.io/pypa/manylinux2014_x86_64``

.. image:: https://quay.io/repository/pypa/manylinux2014_x86_64/status
   :target: https://quay.io/repository/pypa/manylinux2014_x86_64

i686 image: ``quay.io/pypa/manylinux2014_i686``

.. image:: https://quay.io/repository/pypa/manylinux2014_i686/status
   :target: https://quay.io/repository/pypa/manylinux2014_i686

aarch64 image: ``quay.io/pypa/manylinux2014_aarch64``

.. image:: https://quay.io/repository/pypa/manylinux2014_aarch64/status
   :target: https://quay.io/repository/pypa/manylinux2014_aarch64


These images are rebuilt using Travis-CI on every commit to this
repository; see the
`docker/ <https://github.com/pypa/manylinux/tree/manylinux2014/docker>`_
directory for source code.

The images currently contain:

- CPython 3.5, 3.6, 3.7 and 3.8, installed in
  ``/opt/python/<python tag>-<abi tag>``. The directories are named
  after the PEP 425 tags for each environment --
  e.g. ``/opt/python/cp35-cp35m`` contains a CPython 3.5 build, and
  can be used to produce wheels named like
  ``<pkg>-<version>-cp35-cp35m-<arch>.whl``.

- Devel packages for all the libraries that PEP 599 allows you to
  assume are present on the host system

- The `auditwheel <https://pypi.python.org/pypi/auditwheel>`_ tool


Building Docker images
----------------------

To build the Docker images, please run the following command from the
current (root) directory:

    $ PLATFORM=$(uname -m) TRAVIS_COMMIT=latest ./build.sh

Example
-------

An example project which builds x86_64 wheels for each Python interpreter
version can be found here: https://github.com/pypa/python-manylinux-demo. The
repository also contains demo to build i686 and x86_64 wheels with ``manylinux1``
tags.

This demonstrates how to use these docker images in conjunction with auditwheel
to build manylinux-compatible wheels using the free `travis ci <https://travis-ci.org/>`_
continuous integration service.

(NB: for the i686 images running on a x86_64 host machine, it's necessary to run
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

The proposal to upgrade ``manylinux2010`` to ``manylinux2014`` was
discussed in `PEP 599 <https://www.python.org/dev/peps/pep-0599/>`_.

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

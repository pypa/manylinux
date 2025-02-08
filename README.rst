manylinux
=========

Older archives: https://groups.google.com/forum/#!forum/manylinux-discuss

The goal of the manylinux project is to provide a convenient way to
distribute binary Python extensions as wheels on Linux.
This effort has produced `PEP 513 <https://www.python.org/dev/peps/pep-0513/>`_ (manylinux1),
`PEP 571 <https://www.python.org/dev/peps/pep-0571/>`_ (manylinux2010),
`PEP 599 <https://www.python.org/dev/peps/pep-0599/>`_ (manylinux2014),
`PEP 600 <https://www.python.org/dev/peps/pep-0600/>`_ (manylinux_x_y) and
`PEP 656 <https://www.python.org/dev/peps/pep-0656/>`_ (musllinux_x_y).

PEP 513 defined ``manylinux1_x86_64`` and ``manylinux1_i686`` platform tags
and the wheels were built on Centos5. Centos5 reached End of Life (EOL) on
March 31st, 2017.

PEP 571 defined ``manylinux2010_x86_64`` and ``manylinux2010_i686`` platform
tags and the wheels were built on Centos6. Centos6 reached End of Life (EOL)
on November 30th, 2020.

PEP 599 defines the following platform tags: ``manylinux2014_x86_64``,
``manylinux2014_i686``, ``manylinux2014_aarch64``, ``manylinux2014_armv7l``,
``manylinux2014_ppc64``, ``manylinux2014_ppc64le`` and ``manylinux2014_s390x``.
Wheels are built on CentOS 7. CentOS 7 reached End of Life (EOL) on June 30th, 2024.

PEP 600 has been designed to be "future-proof" and does not enforce specific symbols and a specific distro to build.
It only states that a wheel tagged ``manylinux_x_y`` shall work on any distro based on ``glibc>=x.y``. PEP 656 added
``musllinux_x_y`` tags for ``musl>=x.y``.

An overview of distros per glibc version is available at `pep600_compliance <https://github.com/mayeut/pep600_compliance?tab=readme-ov-file#distro-compatibility>`_.

The manylinux project supports:

- ``manylinux2014`` images for ``x86_64``, ``i686``, ``aarch64``, ``ppc64le`` and ``s390x``.

- ``manylinux_2_28`` images for ``x86_64``, ``aarch64``, ``ppc64le`` and ``s390x``.

- ``manylinux_2_34`` images for ``x86_64``, ``aarch64``, ``ppc64le`` and ``s390x``.

- ``musllinux_1_2`` images for ``x86_64``, ``i686``, ``aarch64``, ``ppc64le``, ``s390x`` and ``armv7l``.


Wheel packages compliant with those tags can be uploaded to
`PyPI <https://pypi.python.org>`_ (for instance with `twine
<https://pypi.python.org/pypi/twine>`_) and can be installed with
pip:

+-------------------+------------------+----------------------------+-------------------------------------------+
| ``manylinux`` tag | Client-side pip  | CPython (sources) version  | Distribution default pip compatibility    |
|                   | version required | embedding a compatible pip |                                           |
+===================+==================+============================+===========================================+
| ``manylinux_x_y`` | pip >= 20.3      | 3.8.10+, 3.9.5+, 3.10.0+   | ALT Linux 10+, RHEL 9+, Debian 11+,       |
|                   |                  |                            | Fedora 34+, Mageia 8+,                    |
|                   |                  |                            | Photon OS 3.0 with updates,               |
|                   |                  |                            | Ubuntu 21.04+                             |
+-------------------+------------------+----------------------------+-------------------------------------------+
| ``manylinux2014`` | pip >= 19.3      | 3.7.8+, 3.8.4+, 3.9.0+     | CentOS 7 rh-python38, CentOS 8 python38,  |
|                   |                  |                            | Fedora 32+, Mageia 8+, openSUSE 15.3+,    |
|                   |                  |                            | Photon OS 4.0+ (3.0+ with updates),       |
|                   |                  |                            | Ubuntu 20.04+                             |
+-------------------+------------------+----------------------------+-------------------------------------------+
| ``manylinux2010`` | pip >= 19.0      | 3.7.3+, 3.8.0+             | ALT Linux 9+, CentOS 7 rh-python38,       |
|                   |                  |                            | CentOS 8 python38, Fedora 30+, Mageia 7+, |
|                   |                  |                            | openSUSE 15.3+,                           |
|                   |                  |                            | Photon OS 4.0+ (3.0+ with updates),       |
|                   |                  |                            | Ubuntu 20.04+                             |
+-------------------+------------------+----------------------------+-------------------------------------------+
| ``manylinux1``    | pip >= 8.1.0     | 3.5.2+, 3.6.0+             | ALT Linux 8+, Amazon Linux 1+, CentOS 7+, |
|                   |                  |                            | Debian 9+, Fedora 25+, openSUSE 15.2+,    |
|                   |                  |                            | Mageia 7+, Photon OS 1.0+, Ubuntu 16.04+  |
+-------------------+------------------+----------------------------+-------------------------------------------+

The various manylinux tags allow projects to distribute wheels that are
automatically installed (and work!) on the vast majority of desktop
and server Linux distributions.

This repository hosts several manylinux-related things:


Docker images
-------------

Building manylinux-compatible wheels is not trivial; as a general
rule, binaries built on one Linux distro will only work on other Linux
distros that are the same age or newer. Therefore, if we want to make
binaries that run on most Linux distros, we have to use an old enough
distro.


Rather than forcing you to install an old distro yourself, install Python,
etc., we provide `Docker <https://docker.com/>`_ images where we've
done the work for you. The images are uploaded to `quay.io`_ and are tagged
for repeatable builds.

manylinux_2_34 (AlmaLinux 9 based) - ALPHA
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Caveat:
On x86_64, RHEL 9+ derivatives are using x86-64-v2 target architecture.
While manylinux worked around that when building from sources by intercepting compiler calls to target
x86_64 instead, every library installed with dnf will most likely target the more recent x86-64-v2 which, if
grafted into a wheel, will fail to run on older hardware. There's no PEP to handle micro-architecture variants
yet when it comes to packaging or installing wheels. Auditwheel doesn't detect this either.
See https://github.com/pypa/manylinux/issues/1725

Toolchain: GCC 14

- x86_64 image: ``quay.io/pypa/manylinux_2_34_x86_64``
- aarch64 image: ``quay.io/pypa/manylinux_2_34_aarch64``
- ppc64le image: ``quay.io/pypa/manylinux_2_34_ppc64le``
- s390x image: ``quay.io/pypa/manylinux_2_34_s390x``

Built wheels are also expected to be compatible with other
distros using glibc 2.34 or later, including:

- Debian 12+
- Ubuntu 21.10+
- Fedora 35+
- CentOS/RHEL 9+



manylinux_2_31 (Ubuntu 20.04 based) - armv7l only - BETA
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Caveat:

Only Debian derivatives are available for armv7l. They do not provide recent builds of the GCC toolchain
compatible with a vanilla install of the distribution. As such, we only get the GCC toolchain shipped with
the base distribution.

The package manager & packages names are different than what is found on other manylinux images.
Other images are using RHEL derivatives only for now so using yum/dnf as a package manager and RHEL like
packages names this image is using apt and Debian like packages names.

If one depends on let's say OpenSSL development package, then, the commands to issue to install it are a bit different:

- ``dnf -y install openssl-devel`` on RHEL derivatives
- ``apt-get update && apt-get install -y libssl-dev`` on Debian derivatives


Toolchain: GCC 9

- armv7l image: ``quay.io/pypa/manylinux_2_31_armv7l``

Built wheels are also expected to be compatible with other
distros using glibc 2.31 or later, including:

- Debian 11+
- Ubuntu 20.04+


manylinux_2_28 (AlmaLinux 8 based)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Toolchain: GCC 14

- x86_64 image: ``quay.io/pypa/manylinux_2_28_x86_64``
- aarch64 image: ``quay.io/pypa/manylinux_2_28_aarch64``
- ppc64le image: ``quay.io/pypa/manylinux_2_28_ppc64le``
- s390x image: ``quay.io/pypa/manylinux_2_28_s390x``

Built wheels are also expected to be compatible with other
distros using glibc 2.28 or later, including:

- Debian 10+
- Ubuntu 18.10+
- Fedora 29+
- CentOS/RHEL 8+


manylinux2014 (CentOS 7 based, glibc 2.17)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Toolchain: GCC 10

- x86_64 image: ``quay.io/pypa/manylinux2014_x86_64``
- i686 image: ``quay.io/pypa/manylinux2014_i686``
- aarch64 image: ``quay.io/pypa/manylinux2014_aarch64``
- ppc64le image: ``quay.io/pypa/manylinux2014_ppc64le``
- s390x image: ``quay.io/pypa/manylinux2014_s390x``

Built wheels are also expected to be compatible with other
distros using glibc 2.17 or later, including:

- Debian 8+
- Ubuntu 13.10+
- Fedora 19+
- RHEL 7+


manylinux_2_24 (Debian 9 based) - EOL
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Support for ``manylinux_2_24`` has `ended on January 1st, 2023 <https://github.com/pypa/manylinux/issues/1332>`_.

These images have some caveats mentioned in different issues.

Toolchain: GCC 6

- x86_64 image: ``quay.io/pypa/manylinux_2_24_x86_64``
- i686 image: ``quay.io/pypa/manylinux_2_24_i686``
- aarch64 image: ``quay.io/pypa/manylinux_2_24_aarch64``
- ppc64le image: ``quay.io/pypa/manylinux_2_24_ppc64le``
- s390x image: ``quay.io/pypa/manylinux_2_24_s390x``


manylinux2010 (CentOS 6 based, glibc 2.12 - EOL)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Support for ``manylinux2010`` has `ended on August 1st, 2022 <https://github.com/pypa/manylinux/issues/1281>`_.

Toolchain: GCC 8

- x86-64 image: ``quay.io/pypa/manylinux2010_x86_64``
- i686 image: ``quay.io/pypa/manylinux2010_i686``


manylinux1 (CentOS 5 based, glibc 2.5 - EOL)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Code and details regarding ``manylinux1`` can be found in the `manylinux1 tag <https://github.com/pypa/manylinux/tree/v2024.04.29-manylinux1>`_.

Support for ``manylinux1`` has `ended on January 1st, 2022 <https://github.com/pypa/manylinux/issues/994>`_.

Toolchain: GCC 4.8

- x86-64 image: ``quay.io/pypa/manylinux1_x86_64``
- i686 image: ``quay.io/pypa/manylinux1_i686``


musllinux_1_2 (Alpine Linux 3.21 based, 3.13+ compatible)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Toolchain: GCC 14

- x86_64 image: ``quay.io/pypa/musllinux_1_2_x86_64``
- i686 image: ``quay.io/pypa/musllinux_1_2_i686``
- aarch64 image: ``quay.io/pypa/musllinux_1_2_aarch64``
- ppc64le image: ``quay.io/pypa/musllinux_1_2_ppc64le``
- s390x image: ``quay.io/pypa/musllinux_1_2_s390x``
- armv7l image: ``quay.io/pypa/musllinux_1_2_armv7l``


musllinux_1_1 (Alpine Linux 3.12 based - EOL)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Support for ``musllinux_1_1`` has `ended on November 1st, 2024 <https://github.com/pypa/manylinux/issues/1629>`_.

Toolchain: GCC 9

- x86_64 image: ``quay.io/pypa/musllinux_1_1_x86_64``
- i686 image: ``quay.io/pypa/musllinux_1_1_i686``
- aarch64 image: ``quay.io/pypa/musllinux_1_1_aarch64``
- ppc64le image: ``quay.io/pypa/musllinux_1_1_ppc64le``
- s390x image: ``quay.io/pypa/musllinux_1_1_s390x``


All supported images are rebuilt using GitHub Actions / Travis-CI on every commit to this
repository; see the
`docker/ <https://github.com/pypa/manylinux/tree/main/docker>`_
directory for source code.


Image content
~~~~~~~~~~~~~

All supported images currently contain:

- CPython 3.6, 3.7, 3.8, 3.9, 3.10, 3.11, 3.12, 3.13, 3.13t and PyPy 3.7, 3.8, 3.9, 3.10 installed in
  ``/opt/python/<python tag>-<abi tag>``. The directories are named
  after the PEP 425 tags for each environment --
  e.g. ``/opt/python/cp37-cp37m`` contains a CPython 3.7 build, and
  can be used to produce wheels named like
  ``<pkg>-<version>-cp37-cp37m-<arch>.whl``.

- Development packages for all the libraries that PEP 571/599 list. One should not assume the presence of any other development package.

- The following development tools, installed via `pipx <https://pypi.org/p/pipx>`_ (which is also available):
   - `auditwheel <https://pypi.org/p/auditwheel>`_
   - `cmake <https://pypi.org/p/cmake>`_
   - `patchelf <https://pypi.org/p/patchelf>`_
   - `swig <https://pypi.org/p/swig>`_
   - `uv <https://pypi.org/p/uv>`_ (not available on ``musllinux ppc64le`` & ``musllinux s390x`` yet due to Rust limitations)

- All Python interpreters have the following packages pre-installed:
   - `pip <https://pypi.org/p/pip>`_
   - `build <https://pypi.org/p/build>`_
   - `packaging <https://pypi.org/p/packaging>`_
   - Before Python 3.12, `setuptools <https://pypi.org/p/setuptools>`_ and `wheel <https://pypi.org/p/wheel>`_ are also available.

- The manylinux-interpreters tool which allows to list all available interpreters & install ones missing from the image

  3 commands are available:

  - ``manylinux-interpreters list``

    .. code-block:: bash

      usage: manylinux-interpreters list [-h] [-v] [-i] [--format {text,json}]

      list available or installed interpreters

      options:
        -h, --help            show this help message and exit
        -v, --verbose         display additional information (--format=text only, ignored for --format=json)
        -i, --installed       only list installed interpreters
        --format {text,json}  text is not meant to be machine readable (i.e. the format is not stable)

  - ``manylinux-interpreters ensure-all``

    .. code-block:: bash

      usage: manylinux-interpreters ensure-all [-h]

      make sure all interpreters are installed

      options:
        -h, --help  show this help message and exit

  - ``manylinux-interpreters ensure``

    .. code-block:: bash

      usage: manylinux-interpreters ensure [-h] TAG [TAG ...]

      make sure a list of interpreters are installed

      positional arguments:
        TAG         tag with format '<python tag>-<abi tag>' e.g. 'pp310-pypy310_pp73'

      options:
        -h, --help  show this help message and exit

Note that less common or virtually unheard of flag combinations
(such as ``--with-pydebug`` (``d``) and ``--without-pymalloc`` (absence of ``m``)) are not provided.

Note that `starting with CPython 3.8 <https://docs.python.org/dev/whatsnew/3.8.html#build-and-c-api-changes>`_,
default ``sys.abiflags`` became an empty string: the ``m`` flag for pymalloc
became useless (builds with and without pymalloc are ABI compatible) and so has
been removed. (e.g. ``/opt/python/cp38-cp38``)

Note that PyPy is not available on ppc64le & s390x or on the musllinux images.

Building Docker images
----------------------

To build the Docker images, please run the following command from the
current (root) directory:

    $ PLATFORM=$(uname -m) POLICY=manylinux2014 COMMIT_SHA=latest ./build.sh

Please note that the default Docker build is using `buildx <https://github.com/docker/buildx>`_.
Other frontends can be selected by defining `MANYLINUX_BUILD_FRONTEND`. See `build.sh` for
details.

Updating the requirements
-------------------------

The requirement files are pinned and controlled by uv compile. To update
the pins, run:

    $ nox -s update_python_dependencies

Updating the native dependencies
--------------------------------

Native dependencies are all pinned in the Dockerfile. To update the pins, run the dedicated
nox session. This will add a commit for each update. If you only want to see what would be
updated, you can do a dry run:

    $ nox -s update_native_dependencies [-- --dry-run]



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
<https://github.com/pypa/manylinux/tree/main/pep-513.rst>`_. This is
where the PEP was originally written, so if for some reason you really
want to see the full history of edits it went through, then this is
the place to look.

The proposal to upgrade ``manylinux1`` to ``manylinux2010`` after Centos5
reached EOL was discussed in `PEP 571 <https://www.python.org/dev/peps/pep-0571/>`_.

The proposal to upgrade ``manylinux2010`` to ``manylinux2014`` was
discussed in `PEP 599 <https://www.python.org/dev/peps/pep-0599/>`_.

The proposal for a "future-proof" ``manylinux_x_y`` definition was
discussed in `PEP 600 <https://www.python.org/dev/peps/pep-0600/>`_.

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
`PSF Code of Conduct`_.

.. _PSF Code of Conduct: https://github.com/pypa/.github/blob/main/CODE_OF_CONDUCT.md
.. _`quay.io`: https://quay.io/organization/pypa

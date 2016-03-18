manylinux
=========

Email: manylinux-discuss@googlegroups.com

Archives: https://groups.google.com/forum/#!forum/manylinux-discuss

The goal of the manylinux project is to provide a convenient way to
distribute binary Python extensions as wheels on Linux. So far our
main accomplishment is `PEP 513
<https://www.python.org/dev/peps/pep-0513/>`_, which defines the
``manylinux1_x86_64`` and ``manylinux1_i686`` platform tags. These
tags will soon be allowed on PyPI and supported by pip, and will allow
projects to distribute wheels that are automatically installed (and
work!) on the vast majority of desktop and server Linux distributions.

This repository hosts several manylinux-related things:


Docker images
-------------

.. image:: https://travis-ci.org/pypa/manylinux.svg?branch=master
   :target: https://travis-ci.org/pypa/manylinux

Building manylinux-compatible wheels is not trivial; as a general
rule, binaries built on one Linux distro will only work on other Linux
distros that are the same age or newer. Therefore, if we want to make
binaries that run on most Linux distros, we have to use a very old
distro -- CentOS 5.

Rather than forcing you to install CentOS 5 yourself, install Python,
etc., we provide two `Docker <https://docker.com/>`_ images where we've
done the work for you:

64-bit image (x86-64): ``quay.io/pypa/manylinux1_x86_64``

.. image:: https://quay.io/repository/pypa/manylinux1_x86_64/status
   :target: https://quay.io/repository/pypa/manylinux1_x86_64

32-bit image (i686): ``quay.io/pypa/manylinux1_i686``

.. image:: https://quay.io/repository/pypa/manylinux1_i686/status
   :target: https://quay.io/repository/pypa/manylinux1_i686

This images are rebuilt using Travis-CI on every commit to this
repository; see the
`docker/ <https://github.com/pypa/manylinux/tree/master/docker>`_
directory for source code.

The images currently contain:

- CPython 2.6, 2.7, 3.3, 3.4, and 3.5, installed in ``/opt/<version
  number><soabi flags>``
- Devel packages for all the libraries that PEP 513 allows you to
  assume are present on the host system
- The `auditwheel <https://pypi.python.org/pypi/auditwheel>`_ tool

The "soabi flags" used in naming CPython version directories under ``/opt`` are
`PEP 3149 <https://www.python.org/dev/peps/pep-3149/>`_ ABI flags. Because
wheels created using a CPython (older than 3.3) built with
``--enable-unicode=ucs2`` are not compatible with ``--enable-unicode=ucs4``
interpreters, CPython 2.X builds of both UCS-2 (flags ``m``) and UCS-4 (flags
``mu``) are provided in ``/opt`` since both are commonly found "in the wild."
Other less common or virtually unheard of flag combinations (such as
``--with-pydebug`` (``d``) and ``--without-pymalloc`` (absence of ``m``)) are
not provided.

It'd be good to put an example of how to use these images here, but
that isn't written yet. If you want to know, then bug us on the
mailing list to fill in this section :-). However, one useful tip is that a
list of all interpreters can be obtained with ``/opt/python/*/bin/python``.


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

This repo also has some analysis code that was used when putting
together the original proposal in the ``policy-info/`` directory
(might be useful someday in the future for writing a ``manylinux2``
policy).

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

.. _PyPA Code of Conduct: https://www.pypa.io/en/latest/code-of-conduct/
